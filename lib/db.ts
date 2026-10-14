import "server-only";

/**
 * Database access.
 *
 * Production: any Postgres reachable through DATABASE_URL (Neon via the Vercel
 * Marketplace, Supabase, Railway…). Local development without DATABASE_URL falls
 * back to PGlite — real Postgres compiled to WASM — persisted in ./.data, so the
 * exact same SQL runs everywhere.
 */

export type Row = Record<string, unknown>;

export interface Db {
  query<T = Row>(text: string, params?: unknown[]): Promise<T[]>;
  transaction<R>(fn: (tx: Db) => Promise<R>): Promise<R>;
}

const SCHEMA = /* sql */ `
CREATE TABLE IF NOT EXISTS photos (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  mime        text NOT NULL,
  data        bytea NOT NULL,
  is_public   boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS registrations (
  id           serial PRIMARY KEY,
  name         text NOT NULL,
  phone        text NOT NULL UNIQUE,
  instagram    text,
  photo_id     uuid REFERENCES photos(id) ON DELETE SET NULL,
  sms_consent  boolean NOT NULL DEFAULT true,
  status       text NOT NULL DEFAULT 'new',
  notes        text,
  puller_id    integer,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pullers (
  id               integer PRIMARY KEY CHECK (id > 0),
  name             text NOT NULL,
  nickname         text,
  title            text,
  bio              text,
  photo_url        text,
  card_url         text,
  weight_class     text,
  dominant_arm     text,
  instagram        text,
  is_founder       boolean NOT NULL DEFAULT false,
  hidden           boolean NOT NULL DEFAULT false,
  elo              integer NOT NULL DEFAULT 1000,
  peak_elo         integer NOT NULL DEFAULT 1000,
  registration_id  integer REFERENCES registrations(id) ON DELETE SET NULL,
  joined_on        date NOT NULL DEFAULT CURRENT_DATE,
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS events (
  id           serial PRIMARY KEY,
  slug         text NOT NULL UNIQUE,
  title        text NOT NULL,
  kind         text NOT NULL DEFAULT 'tournament',
  starts_at    timestamptz NOT NULL,
  ends_at      timestamptz,
  venue        text,
  address      text,
  description  text,
  cancelled    boolean NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS matches (
  id                 serial PRIMARY KEY,
  event_id           integer REFERENCES events(id) ON DELETE SET NULL,
  played_on          date NOT NULL DEFAULT CURRENT_DATE,
  arm                text NOT NULL DEFAULT 'right',
  round              text,
  weight_class       text,
  score              text,
  winner_id          integer NOT NULL REFERENCES pullers(id) ON UPDATE CASCADE ON DELETE CASCADE,
  loser_id           integer NOT NULL REFERENCES pullers(id) ON UPDATE CASCADE ON DELETE CASCADE,
  video_url          text,
  is_title_match     boolean NOT NULL DEFAULT false,
  notes              text,
  winner_elo_before  integer,
  winner_elo_after   integer,
  loser_elo_before   integer,
  loser_elo_after    integer,
  created_at         timestamptz NOT NULL DEFAULT now(),
  CHECK (winner_id <> loser_id)
);

CREATE INDEX IF NOT EXISTS matches_winner_idx ON matches (winner_id);
CREATE INDEX IF NOT EXISTS matches_loser_idx ON matches (loser_id);
CREATE INDEX IF NOT EXISTS matches_event_idx ON matches (event_id);
CREATE INDEX IF NOT EXISTS events_starts_idx ON events (starts_at);
`;

/** The eight founders hold the first eight permanent Riser IDs. */
const FOUNDERS: Array<[number, string, string | null, string | null]> = [
  [1, "Harry Lu", "70kg Arm Wrestling Champion", "/founders/harry.jpg"],
  [2, "Erick Kang", "80kg Newcastle Arm Wrestling Champion", "/founders/erick.jpg"],
  [3, "Bhavya Sharma", "70kg Arm Wrestling Silver Medalist", "/founders/bhavya.jpg"],
  [4, "Phillip Nguyen", "80kg NSW Bronze Medalist", "/founders/philip.jpg"],
  [5, "George Lu", null, "/founders/george.jpg"],
  [6, "Tommy", null, null],
  [7, "Luie", null, null],
  [8, "Kelvin", null, null],
];

async function migrate(db: Db) {
  await db.query(SCHEMA);
  const [{ n }] = await db.query<{ n: number }>("SELECT count(*)::int AS n FROM pullers");
  if (n === 0) {
    for (const [id, name, title, card] of FOUNDERS) {
      await db.query(
        `INSERT INTO pullers (id, name, title, card_url, is_founder, joined_on)
         VALUES ($1, $2, $3, $4, true, '2026-01-01') ON CONFLICT (id) DO NOTHING`,
        [id, name, title, card],
      );
    }
  }
}

async function connectPostgres(url: string): Promise<Db> {
  const { default: postgres } = await import("postgres");
  const sql = postgres(url, {
    max: Number(process.env.PG_POOL_MAX) || 3,
    prepare: false, // compatible with transaction-mode poolers (Supabase, Neon pooled)
    idle_timeout: 20,
    onnotice: () => {},
  });
  type Q = { unsafe: (t: string, p?: never[]) => Promise<unknown> };
  const wrap = (q: Q): Db => ({
    async query<T>(text: string, params: unknown[] = []) {
      // Multi-statement text (the schema) cannot carry parameters; use simple protocol.
      const res = params.length ? await q.unsafe(text, params as never[]) : await q.unsafe(text);
      return [...(res as Iterable<T>)];
    },
    transaction() {
      throw new Error("Nested transactions are not supported");
    },
  });
  const root = wrap(sql as unknown as Q);
  return {
    query: root.query,
    transaction: (fn) => sql.begin((tx) => fn(wrap(tx as unknown as Q))) as never,
  };
}

async function connectPglite(): Promise<Db> {
  const { PGlite } = await import("@electric-sql/pglite");
  const { mkdirSync } = await import("node:fs");
  const dir = process.env.PGLITE_DIR || "./.data/pglite";
  mkdirSync(dir, { recursive: true });
  const pg = await PGlite.create(dir);
  type Q = Pick<typeof pg, "query" | "exec">;
  const wrap = (q: Q): Db => ({
    async query<T>(text: string, params: unknown[] = []) {
      if (!params.length && text.includes(";")) {
        const results = await q.exec(text);
        return (results.at(-1)?.rows ?? []) as T[];
      }
      return (await q.query<T>(text, params)).rows;
    },
    transaction() {
      throw new Error("Nested transactions are not supported");
    },
  });
  const root = wrap(pg);
  return {
    query: root.query,
    transaction: (fn) => pg.transaction((tx) => fn(wrap(tx))),
  };
}

const globalForDb = globalThis as unknown as { __risersDb?: Promise<Db> };

export function getDb(): Promise<Db> {
  if (!globalForDb.__risersDb) {
    globalForDb.__risersDb = (async () => {
      const url = process.env.DATABASE_URL || process.env.POSTGRES_URL;
      if (!url && process.env.VERCEL) {
        throw new Error("DATABASE_URL is not set. Connect a Postgres database in Vercel → Storage.");
      }
      const db = url ? await connectPostgres(url) : await connectPglite();
      await migrate(db);
      return db;
    })().catch((err) => {
      globalForDb.__risersDb = undefined;
      throw err;
    });
  }
  return globalForDb.__risersDb;
}
