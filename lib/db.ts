import "server-only";
import { quoteOdds } from "./odds";
import { awardResultsChalk } from "./results";

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

CREATE TABLE IF NOT EXISTS tv_reels (
  id          serial PRIMARY KEY,
  url         text NOT NULL,
  title       text NOT NULL,
  caption     text,
  posted_on   date,
  sort_order  integer NOT NULL DEFAULT 0,
  hidden      boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS shop_interest (
  id          serial PRIMARY KEY,
  product     text NOT NULL,
  name        text NOT NULL,
  phone       text NOT NULL,
  notes       text,
  emailed     boolean NOT NULL DEFAULT false,
  done        boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS accounts (
  id            serial PRIMARY KEY,
  handle        text NOT NULL UNIQUE,
  display_name  text NOT NULL,
  pass_hash     text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sessions (
  token_hash  text PRIMARY KEY,
  account_id  integer NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz NOT NULL
);

-- Old handles, so profile links keep working after a member changes their @handle.
CREATE TABLE IF NOT EXISTS handle_history (
  old_handle  text PRIMARY KEY,
  account_id  integer NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  changed_at  timestamptz NOT NULL DEFAULT now()
);

-- One-time password reset links an organiser makes in Admin HQ and sends to the member.
CREATE TABLE IF NOT EXISTS password_resets (
  token_hash  text PRIMARY KEY,
  account_id  integer NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  expires_at  timestamptz NOT NULL,
  used_at     timestamptz
);

CREATE TABLE IF NOT EXISTS login_attempts (
  handle  text NOT NULL,
  at      timestamptz NOT NULL DEFAULT now()
);

-- 88Risers coins: a ledger, so the balance is always the sum and every grant is traceable.
-- ref makes payouts idempotent (one supermatch payout per account).
CREATE TABLE IF NOT EXISTS coin_tx (
  id          serial PRIMARY KEY,
  account_id  integer NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  amount      integer NOT NULL,
  reason      text NOT NULL,
  ref         text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (account_id, ref)
);

CREATE TABLE IF NOT EXISTS supermatches (
  id          serial PRIMARY KEY,
  slug        text NOT NULL UNIQUE,
  title       text NOT NULL,
  blurb       text,
  a_id        integer NOT NULL REFERENCES pullers(id) ON UPDATE CASCADE,
  b_id        integer NOT NULL REFERENCES pullers(id) ON UPDATE CASCADE,
  closes_at   timestamptz NOT NULL,
  reward      integer NOT NULL DEFAULT 88,
  winner_id   integer REFERENCES pullers(id) ON UPDATE CASCADE,
  settled_at  timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS predictions (
  match_id    integer NOT NULL REFERENCES supermatches(id) ON DELETE CASCADE,
  account_id  integer NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  pick_id     integer NOT NULL,
  stake       integer NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (match_id, account_id)
);
-- Databases that got an early version of this table (from a preview build) lack the stake column.
ALTER TABLE predictions ADD COLUMN IF NOT EXISTS stake integer NOT NULL DEFAULT 0;
-- Which arm the supermatch is pulled with ('left' or 'right').
ALTER TABLE supermatches ADD COLUMN IF NOT EXISTS arm text NOT NULL DEFAULT 'right';
-- Odds locked in when the bet was placed (null on bets from before odds were locked).
ALTER TABLE predictions ADD COLUMN IF NOT EXISTS odds numeric(8, 2);

-- Coin store purchases: cosmetics (equipped on the account card), perks (a code the club honours)
-- and giveaway entries. code is shown to the member and checked by organisers.
CREATE TABLE IF NOT EXISTS redemptions (
  id          serial PRIMARY KEY,
  account_id  integer NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  item        text NOT NULL,
  cost        integer NOT NULL,
  code        text NOT NULL UNIQUE,
  fulfilled   boolean NOT NULL DEFAULT false,
  won         boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS account_style (
  account_id  integer PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
  frame       text,
  title       text,
  badge       boolean NOT NULL DEFAULT false
);

-- Chalk: season points from meets. A meet is a Sydney date an organiser opened check-in for.
CREATE TABLE IF NOT EXISTS meets (
  id             serial PRIMARY KEY,
  day            date NOT NULL UNIQUE,
  code           text NOT NULL,
  is_tournament  boolean NOT NULL DEFAULT false,
  open           boolean NOT NULL DEFAULT true,
  first_id       integer REFERENCES accounts(id) ON DELETE SET NULL,
  second_id      integer REFERENCES accounts(id) ON DELETE SET NULL,
  third_id       integer REFERENCES accounts(id) ON DELETE SET NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS checkins (
  meet_id     integer NOT NULL REFERENCES meets(id) ON DELETE CASCADE,
  account_id  integer NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  at          timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (meet_id, account_id)
);
-- Ledger like coin_tx: one row per award; ref makes each award happen once.
CREATE TABLE IF NOT EXISTS chalk_tx (
  id          serial PRIMARY KEY,
  account_id  integer NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  season      integer NOT NULL,
  amount      integer NOT NULL,
  reason      text NOT NULL,
  ref         text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (account_id, ref)
);
CREATE INDEX IF NOT EXISTS chalk_tx_season ON chalk_tx (season, account_id);
ALTER TABLE accounts ADD COLUMN IF NOT EXISTS invited_by integer REFERENCES accounts(id) ON DELETE SET NULL;
-- A Riser number someone asked for when registering ($2 gold coin donation).
ALTER TABLE registrations ADD COLUMN IF NOT EXISTS requested_id integer;
-- "I'm coming with a friend" on the join form.
ALTER TABLE registrations ADD COLUMN IF NOT EXISTS with_friend boolean NOT NULL DEFAULT false;
ALTER TABLE registrations ADD COLUMN IF NOT EXISTS friend_name text;
-- Placings at competitions (outside comps included), shown on Riser profiles.
CREATE TABLE IF NOT EXISTS comp_results (
  id          serial PRIMARY KEY,
  puller_id   integer NOT NULL REFERENCES pullers(id) ON UPDATE CASCADE ON DELETE CASCADE,
  event       text NOT NULL,
  division    text,
  place       integer NOT NULL CHECK (place > 0),
  played_on   date,
  season      integer NOT NULL,
  notes       text,
  created_at  timestamptz NOT NULL DEFAULT now()
);
-- A Riser's member account, so supermatches and podiums can award them Chalk.
ALTER TABLE pullers ADD COLUMN IF NOT EXISTS account_id integer UNIQUE REFERENCES accounts(id) ON DELETE SET NULL;
CREATE TABLE IF NOT EXISTS arcade_scores (
  account_id  integer NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  game        text NOT NULL,
  level       text NOT NULL,
  best        integer NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (account_id, game, level)
);
CREATE TABLE IF NOT EXISTS game_scores (
  account_id  integer PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
  best        integer NOT NULL,
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- Pin Run: coins grabbed in runs (Temple coins, separate from 88Risers coins) and lion skins.
CREATE TABLE IF NOT EXISTS pinrun_wallet (
  account_id  integer PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
  coins       integer NOT NULL DEFAULT 0 CHECK (coins >= 0),
  skin        text NOT NULL DEFAULT 'stone',
  owned       text[] NOT NULL DEFAULT '{stone}',
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- Organisers can unlock Pin Run Level 2 for an account without the 5,000 score.
ALTER TABLE pinrun_wallet ADD COLUMN IF NOT EXISTS l2 boolean NOT NULL DEFAULT false;
-- ...and Level 3 without the 5,000 on Level 2.
ALTER TABLE pinrun_wallet ADD COLUMN IF NOT EXISTS l3 boolean NOT NULL DEFAULT false;
-- Coin sinks: run boosts in stock, ability upgrade tiers per lion, golden lions.
ALTER TABLE pinrun_wallet ADD COLUMN IF NOT EXISTS boosts jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE pinrun_wallet ADD COLUMN IF NOT EXISTS ups jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE pinrun_wallet ADD COLUMN IF NOT EXISTS gold text[] NOT NULL DEFAULT '{}';

CREATE TABLE IF NOT EXISTS pinrun_tx (
  id          serial PRIMARY KEY,
  account_id  integer NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  amount      integer NOT NULL,
  reason      text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS pinrun_tx_account ON pinrun_tx (account_id, created_at);

-- Pin Run Club Raid: one Riser boss at a time with a health pool the whole club chips at on Level 3.
CREATE TABLE IF NOT EXISTS pinrun_raids (
  id           serial PRIMARY KEY,
  boss_id      integer NOT NULL,
  hp_max       integer NOT NULL,
  hp           integer NOT NULL,
  started_at   timestamptz NOT NULL DEFAULT now(),
  defeated_at  timestamptz
);
CREATE TABLE IF NOT EXISTS pinrun_raid_hits (
  raid_id     integer NOT NULL REFERENCES pinrun_raids(id) ON DELETE CASCADE,
  account_id  integer NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  damage      integer NOT NULL DEFAULT 0,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (raid_id, account_id)
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
  [3, "Phillip Nguyen", "80kg NSW Bronze Medalist", "/founders/phillip.jpg"],
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

/** First 88RisersTV reels, in channel order. Added once; skipped if a reel with that code exists. */
const TV_SEED = ["DdbKrJFB7cB", "Dd0Nzb6h_SC", "DeA5EcEBkFc", "DeLgi4JThHG", "DeXuPBfvS9-"];

const MIGRATION_MARKER = "founders_v30";

/** [meta key, account handle, account name, Riser #, Riser name] for one-off account links. */
const ACCOUNT_LINKS: Array<[string, string, string, number, string]> = [
  ["link_harry_001", "savethepenguin9", "harry lu", 1, "harry lu"],
  ["link_erick_008", "daddy", "erick", 8, "erick%"],
];

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
    } else {
      // Databases seeded by the first release: move founders to their real numbers.
      // Matches follow via ON UPDATE CASCADE. Rows an admin already renamed are left alone.
      // Skipped on databases that already reached founders_v2.
      const [renumbered] = await tx.query(`SELECT 1 FROM meta WHERE key = 'founders_v2'`);
      if (!renumbered) await renumberFounders(tx);
    }
    // Kelvin's champion card (added after launch). Keeps a title an admin already set.
    await tx.query(
      `UPDATE pullers SET card_url = $2, title = coalesce(title, $3) WHERE id = $1 AND name ILIKE $4 AND is_founder
       AND (card_url IS NULL OR card_url LIKE '/founders/%')`,
      [5, "/founders/kelvin.jpg", "85kg+ Bushy's Amateur 2nd Place", "Kelvin%"],
    );
    // Phillip's new card (the old file was removed). Leaves a card an admin uploaded alone.
    await tx.query(`UPDATE pullers SET card_url = $1 WHERE card_url = $2`, [
      "/founders/phillip.jpg",
      "/founders/philip.jpg",
    ]);
    // Founder nicknames. Keeps a nickname an admin already set.
    await tx.query(
      `UPDATE pullers SET nickname = $2 WHERE id = $1 AND name ILIKE $3 AND is_founder AND coalesce(nickname, '') = ''`,
      [5, "Kelvinator", "Kelvin%"],
    );
    for (const [i, code] of TV_SEED.entries()) {
      await tx.query(
        `INSERT INTO tv_reels (url, title, sort_order)
         SELECT $1, $2, $3 WHERE NOT EXISTS (SELECT 1 FROM tv_reels WHERE url LIKE $4)`,
        [`https://www.instagram.com/reel/${code}/`, `Episode ${String(i + 1).padStart(2, "0")}`, i + 1, `%/${code}/%`],
      );
    }
    // November Supermatch: Bhavya (#004) vs Harry (#001). Voting closes at the match; editable in admin.
    await tx.query(
      `INSERT INTO supermatches (slug, title, blurb, a_id, b_id, closes_at, reward, arm)
       SELECT $1, $2, $3, 4, 1, $4, 88, 'left'
       WHERE EXISTS (SELECT 1 FROM pullers WHERE id = 4) AND EXISTS (SELECT 1 FROM pullers WHERE id = 1)
       ON CONFLICT (slug) DO NOTHING`,
      [
        "november-2026",
        "November Supermatch",
        "Silver medallist Bhavya takes on 70kg champion Harry. Two founders, one table, bragging rights for the year.",
        "2026-11-29T18:00:00+11:00",
      ],
    );
    // Bets placed before odds were locked: replay each match in betting order and give every
    // bet the price it would have been shown (the first bet on a match gets 2.00×).
    const unpriced = await tx.query<{ match_id: number }>(`SELECT DISTINCT p.match_id FROM predictions p JOIN supermatches m ON m.id = p.match_id
       WHERE p.odds IS NULL AND m.settled_at IS NULL`);
    for (const { match_id } of unpriced) {
      const [sm] = await tx.query<{ a_id: number }>(`SELECT a_id FROM supermatches WHERE id = $1`, [match_id]);
      const bets = await tx.query<{ account_id: number; pick_id: number; stake: number; odds: string | null }>(
        `SELECT account_id, pick_id, stake, odds FROM predictions WHERE match_id = $1 ORDER BY created_at, account_id`,
        [match_id],
      );
      const pools = { a: 0, b: 0 };
      for (const bet of bets) {
        const side = bet.pick_id === sm.a_id ? "a" : "b";
        if (bet.odds == null) {
          await tx.query(`UPDATE predictions SET odds = $3 WHERE match_id = $1 AND account_id = $2`, [
            match_id, bet.account_id, quoteOdds(side, pools),
          ]);
        }
        pools[side] += bet.stake;
      }
    }
    // Kelvin Gian (#005): 2nd at Bushy's Amateur comp, 85kg+. Once only; editable in admin.
    const [kelvinDone] = await tx.query(`SELECT 1 FROM meta WHERE key = 'result_kelvin_bushys'`);
    if (!kelvinDone) {
      await tx.query(
        `INSERT INTO comp_results (puller_id, event, division, place, season)
         SELECT 5, 'Bushy''s Amateur Comp', '85kg+', 2, 2026 WHERE EXISTS (SELECT 1 FROM pullers WHERE id = 5)`,
      );
      await tx.query(`INSERT INTO meta (key, value) VALUES ('result_kelvin_bushys', now()::text)`);
    }
    // Pay podium Chalk for results whose Riser is linked to an account (refs make it once only).
    const linked = await tx.query<{ id: number }>(
      `SELECT DISTINCT p.id FROM pullers p JOIN comp_results r ON r.puller_id = p.id WHERE p.account_id IS NOT NULL`,
    );
    for (const { id } of linked) await awardResultsChalk(tx, id);
    // Top Riser prize announced: the custom katana. Once only, so later admin edits stick.
    const [katanaDone] = await tx.query(`SELECT 1 FROM meta WHERE key = 'top_prize_katana_v1'`);
    if (!katanaDone) {
      await tx.query(
        `INSERT INTO meta (key, value) VALUES ('chalk_top_prize', $1) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`,
        ["A custom 88 Risers katana: real, sharp, one of one"],
      );
      await tx.query(`INSERT INTO meta (key, value) VALUES ('top_prize_katana_v1', now()::text)`);
    }
    // Felix opted in to reserve #017 ($2 gold coin). Once only, and only if exactly one open
    // registration is named Felix and #017 is still free.
    const [felixDone] = await tx.query(`SELECT 1 FROM meta WHERE key = 'reserve_felix_17'`);
    if (!felixDone) {
      const felix = await tx.query<{ id: number }>(
        `SELECT id FROM registrations WHERE name ILIKE 'felix%' AND puller_id IS NULL AND status <> 'archived'`,
      );
      const [clash] = await tx.query(
        `SELECT 1 FROM pullers WHERE id = 17 UNION ALL
         SELECT 1 FROM registrations WHERE requested_id = 17 AND puller_id IS NULL AND status <> 'archived'`,
      );
      if (felix.length === 1 && !clash) {
        await tx.query(`UPDATE registrations SET requested_id = 17, updated_at = now() WHERE id = $1`, [felix[0].id]);
        await tx.query(`INSERT INTO meta (key, value) VALUES ('reserve_felix_17', now()::text)`);
      }
    }
    // One-off links of member accounts to their Riser numbers. Each runs once, and only if both
    // sides match by name and neither is linked yet.
    for (const [key, handle, displayName, riserId, riserName] of ACCOUNT_LINKS) {
      const [linkDone] = await tx.query(`SELECT 1 FROM meta WHERE key = $1`, [key]);
      if (linkDone) continue;
      const [acct] = await tx.query<{ id: number }>(
        `SELECT a.id FROM accounts a
         WHERE a.handle = $1 AND a.display_name ILIKE $2
           AND NOT EXISTS (SELECT 1 FROM pullers p WHERE p.account_id = a.id)`,
        [handle, displayName],
      );
      const [riser] = await tx.query(`SELECT 1 FROM pullers WHERE id = $1 AND name ILIKE $2 AND account_id IS NULL`, [riserId, riserName]);
      if (acct && riser) {
        await tx.query(`UPDATE pullers SET account_id = $1 WHERE id = $2`, [acct.id, riserId]);
        const { awardResultsChalk } = await import("./results");
        await awardResultsChalk(tx, riserId);
        await tx.query(`INSERT INTO meta (key, value) VALUES ($1, now()::text)`, [key]);
      }
    }
    // George asked for Pin Run Level 2 unlocked on his account. Once only.
    const [l2Done] = await tx.query(`SELECT 1 FROM meta WHERE key = 'l2_unlock_george'`);
    if (!l2Done) {
      const [g] = await tx.query<{ id: number }>(`SELECT id FROM accounts WHERE handle = 'georgelu721'`);
      if (g) {
        await tx.query(`INSERT INTO pinrun_wallet (account_id, l2) VALUES ($1, true) ON CONFLICT (account_id) DO UPDATE SET l2 = true`, [g.id]);
        await tx.query(`INSERT INTO meta (key, value) VALUES ('l2_unlock_george', now()::text)`);
      }
    }
    // George asked for every Pin Run lion on his account. Once only (coins and equipped lion untouched).
    const [lionsDone] = await tx.query(`SELECT 1 FROM meta WHERE key = 'all_lions_george'`);
    if (!lionsDone) {
      const [g] = await tx.query<{ id: number }>(`SELECT id FROM accounts WHERE handle = 'georgelu721'`);
      if (g) {
        const all = ["stone", "sakura", "jade", "wave", "crystal", "flame", "thunder", "moon", "eclipse"];
        await tx.query(
          `INSERT INTO pinrun_wallet (account_id, owned) VALUES ($1, $2::text[])
           ON CONFLICT (account_id) DO UPDATE SET owned = (SELECT array_agg(DISTINCT x) FROM unnest(pinrun_wallet.owned || $2::text[]) x), updated_at = now()`,
          [g.id, all],
        );
        await tx.query(`INSERT INTO meta (key, value) VALUES ('all_lions_george', now()::text)`);
      }
    }
    // The November supermatch is left arm. Once only, so a later admin edit isn't overwritten.
    const [armDone] = await tx.query(`SELECT 1 FROM meta WHERE key = 'sm_arm_v1'`);
    if (!armDone) {
      await tx.query(`UPDATE supermatches SET arm = 'left' WHERE slug = 'november-2026'`);
      await tx.query(`INSERT INTO meta (key, value) VALUES ('sm_arm_v1', now()::text)`);
    }
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
  const dir = building || isPreview() ? "memory://" : process.env.PGLITE_DIR || "./.data/pglite";
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

/** Vercel preview/development deployments. They never get the live database (see getDb). */
const isPreview = () => !!process.env.VERCEL_ENV && process.env.VERCEL_ENV !== "production";

const globalForDb = globalThis as unknown as { __risersDb?: Promise<Db> };

export function getDb(): Promise<Db> {
  if (!globalForDb.__risersDb) {
    globalForDb.__risersDb = (async () => {
      // Preview deployments share env vars with production, so ignore DATABASE_URL there:
      // a half-finished branch must never migrate or write to the live database.
      // Set PREVIEW_DATABASE_URL to give previews a separate Postgres; otherwise they get a
      // throwaway in-memory database with the seed data.
      const url = isPreview()
        ? process.env.PREVIEW_DATABASE_URL
        : process.env.DATABASE_URL || process.env.POSTGRES_URL;
      if (!url && process.env.VERCEL && !isPreview()) {
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
