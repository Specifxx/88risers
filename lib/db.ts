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

CREATE TABLE IF NOT EXISTS meta (
  key    text PRIMARY KEY,
  value  text
);

CREATE INDEX IF NOT EXISTS matches_winner_idx ON matches (winner_id);
CREATE INDEX IF NOT EXISTS matches_loser_idx ON matches (loser_id);
CREATE INDEX IF NOT EXISTS matches_event_idx ON matches (event_id);
CREATE INDEX IF NOT EXISTS events_starts_idx ON events (starts_at);
`;

/** The eight founders hold the first eight permanent Riser IDs. */
const FOUNDERS: Array<[number, string, string | null, string | null]> = [
  [1, "Harry Lu", "70kg Arm Wrestling Champion", "/founders/harry.jpg"],
  [2, "George Lu", null, "/founders/george.jpg"],
  [3, "Phillip Nguyen", "80kg NSW Bronze Medalist", "/founders/philip.jpg"],
  [4, "Bhavya Sharma", "70kg Arm Wrestling Silver Medalist", "/founders/bhavya.jpg"],
  [5, "Kelvin Gian", "85kg+ Bushy's Amateur 2nd Place", "/founders/kelvin.jpg"],
  [6, "Tommy Cao", null, null],
  [7, "Luie Hoang", null, null],
  [8, "Erick Kang", "80kg Newcastle Arm Wrestling Champion", "/founders/erick.jpg"],
];

/** First release's placeholder numbering: [old id, old name, new id, new name]. */
const FOUNDER_RENUMBER: Array<[number, string, number, string]> = [
  [1, "Harry Lu", 1, "Harry Lu"],
  [5, "George Lu", 2, "George Lu"],
  [4, "Phillip Nguyen", 3, "Phillip Nguyen"],
  [3, "Bhavya Sharma", 4, "Bhavya Sharma"],
  [8, "Kelvin", 5, "Kelvin Gian"],
  [6, "Tommy", 6, "Tommy Cao"],
  [7, "Luie", 7, "Luie Hoang"],
  [2, "Erick Kang", 8, "Erick Kang"],
];

const MIGRATION_MARKER = "founders_v3";

async function migrate(db: Db) {
  // Fast path for every cold start after the first: one tiny query instead of the whole schema.
  // Bump MIGRATION_MARKER whenever SCHEMA or the data steps below change.
  try {
    const done = await db.query(`SELECT 1 FROM meta WHERE key = $1`, [MIGRATION_MARKER]);
    if (done.length) return;
  } catch {
    // meta table doesn't exist yet — fresh database
  }
  await db.query(SCHEMA);
  await db.transaction(async (tx) => {
    // Whoever inserts this marker runs the step; concurrent cold starts wait on the row and skip.
    const claimed = await tx.query(
      `INSERT INTO meta (key, value) VALUES ($1, now()::text) ON CONFLICT (key) DO NOTHING RETURNING key`,
      [MIGRATION_MARKER],
    );
    if (!claimed.length) return;
    const [{ n }] = await tx.query<{ n: number }>("SELECT count(*)::int AS n FROM pullers");
    if (n === 0) {
      for (const [id, name, title, card] of FOUNDERS) {
        await tx.query(
          `INSERT INTO pullers (id, name, title, card_url, is_founder, joined_on)
           VALUES ($1, $2, $3, $4, true, '2026-01-01')`,
          [id, name, title, card],
        );
      }
      return;
    }
    // Databases seeded by the first release: move founders to their real numbers.
    // Matches follow via ON UPDATE CASCADE. Rows an admin already renamed are left alone.
    // Skipped on databases that already reached founders_v2.
    const [renumbered] = await tx.query(`SELECT 1 FROM meta WHERE key = 'founders_v2'`);
    if (!renumbered) await renumberFounders(tx);
    // Kelvin's champion card (added after launch). Keeps a title an admin already set.
    await tx.query(
      `UPDATE pullers SET card_url = $2, title = coalesce(title, $3) WHERE id = $1 AND name ILIKE $4 AND is_founder`,
      [5, "/founders/kelvin.jpg", "85kg+ Bushy's Amateur 2nd Place", "Kelvin%"],
    );
  });
}

async function renumberFounders(tx: Db) {
  const OFFSET = 100000;
  const moved: Array<[number, number, string]> = [];
  for (const [oldId, oldName, newId, newName] of FOUNDER_RENUMBER) {
    const r = await tx.query(
      `UPDATE pullers SET id = id + ${OFFSET} WHERE id = $1 AND name = $2 AND is_founder RETURNING id`,
      [oldId, oldName],
    );
    if (r.length) moved.push([oldId, newId, newName]);
  }
  for (const [oldId, newId, newName] of moved) {
    await tx.query(`UPDATE pullers SET id = $2, name = $3 WHERE id = $1`, [oldId + OFFSET, newId, newName]);
    await tx.query(`UPDATE registrations SET puller_id = $2 WHERE puller_id = $1`, [oldId, newId]);
  }
}

async function connectPostgres(url: string): Promise<Db> {
  const { default: postgres } = await import("postgres");
  const sql = postgres(url, {
    max: Number(process.env.PG_POOL_MAX) || 3,
    prepare: false, // compatible with transaction-mode poolers (Supabase, Neon pooled)
    idle_timeout: 20,
    connect_timeout: 10, // serverless databases (Neon free tier) can take a few seconds to wake
    // The driver's default reconnect delay grows to 20s after repeated failures, which
    // stalls every later request on a warm instance. Reconnect promptly; withRetry paces us.
    backoff: () => 0.25,
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
  // During `next build` several workers prerender in parallel; give them a throwaway database.
  const building = process.env.NEXT_PHASE === "phase-production-build";
  const dir = building ? "memory://" : process.env.PGLITE_DIR || "./.data/pglite";
  if (!building) mkdirSync(dir, { recursive: true });
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

/** Errors worth retrying: the connection dropped or the database is still waking up. */
function isTransient(err: unknown) {
  const code = String((err as { code?: unknown })?.code ?? "");
  return (
    /^(ECONNRESET|ECONNREFUSED|ETIMEDOUT|EPIPE|EAI_AGAIN|CONNECTION_CLOSED|CONNECTION_ENDED|CONNECTION_DESTROYED|CONNECT_TIMEOUT)$/.test(code) ||
    /^(08|57P0[1-3])/.test(code) // connection exceptions, server shutting down / starting up
  );
}

async function withRetry<R>(fn: () => Promise<R>, attempts = 3): Promise<R> {
  for (let i = 1; ; i++) {
    try {
      return await fn();
    } catch (err) {
      if (i >= attempts || !isTransient(err)) throw err;
      await new Promise((r) => setTimeout(r, 300 * 2 ** (i - 1)));
    }
  }
}

function resilient(db: Db): Db {
  return {
    query: (text, params) => withRetry(() => db.query(text, params)),
    // A transaction that failed on a dropped connection was rolled back, so it is safe to rerun.
    transaction: (fn) => withRetry(() => db.transaction(fn)),
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
      const db = resilient(url ? await connectPostgres(url) : await connectPglite());
      await migrate(db);
      return db;
    })().catch((err) => {
      globalForDb.__risersDb = undefined;
      throw err;
    });
  }
  return globalForDb.__risersDb;
}
