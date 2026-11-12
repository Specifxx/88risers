import "server-only";
import { randomInt } from "node:crypto";
import type { Db } from "./db";
import { getDb } from "./db";
import { SITE } from "./site";

/**
 * Chalk: season points for showing up and competing. Seasons run January to December
 * (Sydney time). Everyone who reaches the target completes the Lift and gets the Lift
 * prize; whoever tops the Chalkboard at the end of the year is crowned Top Riser.
 */
export const CHALK = {
  checkin: 2,
  invite: 3,
  podium: [10, 6, 4] as const,
  /** Pulling in a club supermatch, and the extra for winning it. */
  supermatch: 5,
  supermatchWin: 5,
};
export const DEFAULT_TARGET = 20;

const sydney = (opts: Intl.DateTimeFormatOptions) => new Intl.DateTimeFormat("en-CA", { timeZone: SITE.timeZone, ...opts });
/** Today's date in Sydney as YYYY-MM-DD. */
export const sydneyToday = () => sydney({ year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
/**
 * Seasons are named by the year they start in and normally end on 31 December. A season can run
 * longer: 2026 ends at the Rhodes Open on Sunday 4 April 2027, and the next season starts the day after.
 */
const SEASON_END_DAY: Record<number, string> = { 2026: "2027-04-04" };
/** The season's last day, YYYY-MM-DD. */
export const seasonEndDay = (season: number) => SEASON_END_DAY[season] ?? `${season}-12-31`;
/** The season's first day, YYYY-MM-DD (the day after the previous one ended). */
export const seasonStartDay = (season: number) => {
  const prev = SEASON_END_DAY[season - 1];
  if (!prev) return `${season}-01-01`;
  const d = new Date(`${prev}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
};
/** Which season a date (YYYY-MM-DD) belongs to. */
export const seasonOf = (day: string) => {
  const y = Number(day.slice(0, 4));
  return day <= seasonEndDay(y - 1) ? y - 1 : y;
};
export const currentSeason = () => seasonOf(sydneyToday());
/** "4 April 2027": when the season's Top Riser is crowned. */
export const seasonEndLabel = (season: number) =>
  new Intl.DateTimeFormat("en-AU", { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" }).format(
    new Date(`${seasonEndDay(season)}T00:00:00Z`),
  );
/** Last moment of the season: 11:59pm Sydney on its last day. */
/** "23 Oct" from a YYYY-MM-DD meet day, for Chalk history. */
export const meetLabel = (day: string) =>
  new Intl.DateTimeFormat("en-AU", { day: "numeric", month: "short", timeZone: "UTC" }).format(new Date(`${day}T00:00:00Z`));
export const seasonEnd = (season: number) => {
  const day = seasonEndDay(season);
  const m = Number(day.slice(5, 7));
  return new Date(`${day}T23:59:59${m >= 4 && m <= 9 ? "+10:00" : "+11:00"}`); // AEST in winter, AEDT in summer
};

/* ─────────── Settings (admin HQ) ─────────── */

export interface ChalkSettings {
  target: number;
  liftPrize: string;
  topPrize: string;
}

export async function chalkSettings(): Promise<ChalkSettings> {
  const db = await getDb();
  const rows = await db.query<{ key: string; value: string }>(
    `SELECT key, value FROM meta WHERE key IN ('chalk_target', 'chalk_lift_prize', 'chalk_top_prize')`,
  );
  const get = (k: string) => rows.find((r) => r.key === k)?.value;
  const target = Number(get("chalk_target"));
  return {
    target: Number.isFinite(target) && target > 0 ? target : DEFAULT_TARGET,
    liftPrize: get("chalk_lift_prize") || "A season reward from the club",
    topPrize: get("chalk_top_prize") || "A custom 88 Risers katana: real, sharp, one of one",
  };
}

export async function saveChalkSettings(s: ChalkSettings) {
  const db = await getDb();
  for (const [key, value] of [
    ["chalk_target", String(s.target)],
    ["chalk_lift_prize", s.liftPrize],
    ["chalk_top_prize", s.topPrize],
  ]) {
    await db.query(`INSERT INTO meta (key, value) VALUES ($1, $2) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`, [key, value]);
  }
}

/* ─────────── Ledger ─────────── */

/** Awards Chalk once per ref; returns whether it was credited. */
export async function awardChalk(db: Db, accountId: number, season: number, amount: number, reason: string, ref: string | null) {
  const r = await db.query(
    `INSERT INTO chalk_tx (account_id, season, amount, reason, ref) VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (account_id, ref) DO NOTHING RETURNING id`,
    [accountId, season, amount, reason, ref],
  );
  return r.length > 0;
}

/** Chalk for a Riser with no linked account yet (moves to their account when they link one). */
export async function awardRiserChalk(db: Db, pullerId: number, season: number, amount: number, reason: string, ref: string) {
  const r = await db.query(
    `INSERT INTO chalk_tx (account_id, puller_id, season, amount, reason, ref) VALUES (NULL, $1, $2, $3, $4, $5)
     ON CONFLICT (puller_id, ref) WHERE account_id IS NULL DO NOTHING RETURNING id`,
    [pullerId, season, amount, reason, ref],
  );
  return r.length > 0;
}

/** Moves a Riser's held Chalk onto the account they've just linked (anything already there isn't doubled). */
export async function claimRiserChalk(db: Db, pullerId: number, accountId: number) {
  await db.query(
    `DELETE FROM chalk_tx r WHERE r.puller_id = $1 AND r.account_id IS NULL
       AND EXISTS (SELECT 1 FROM chalk_tx a WHERE a.account_id = $2 AND a.ref = r.ref)`,
    [pullerId, accountId],
  );
  await db.query(`UPDATE chalk_tx SET account_id = $2 WHERE puller_id = $1 AND account_id IS NULL`, [pullerId, accountId]);
}

/** Season Chalk held by a Riser profile that isn't linked to an account. */
export async function riserChalkOf(pullerId: number, season = currentSeason()) {
  const db = await getDb();
  const [r] = await db.query<{ n: number }>(
    `SELECT coalesce(sum(amount), 0)::int AS n FROM chalk_tx WHERE puller_id = $1 AND account_id IS NULL AND season = $2`,
    [pullerId, season],
  );
  return r.n;
}

export async function chalkOf(accountId: number, season = currentSeason()) {
  const db = await getDb();
  const [r] = await db.query<{ n: number }>(
    `SELECT coalesce(sum(amount), 0)::int AS n FROM chalk_tx WHERE account_id = $1 AND season = $2`,
    [accountId, season],
  );
  return r.n;
}

export interface ChalkRow {
  amount: number;
  reason: string;
  created_at: string;
}

export async function chalkHistory(accountId: number, season = currentSeason()) {
  const db = await getDb();
  return db.query<ChalkRow>(
    `SELECT amount, reason, created_at FROM chalk_tx WHERE account_id = $1 AND season = $2 ORDER BY id DESC LIMIT 40`,
    [accountId, season],
  );
}

/** Has this account completed the Lift in any season? (For the achievement.) */
export async function liftCompletedEver(accountId: number, target: number) {
  const db = await getDb();
  const [r] = await db.query<{ done: boolean }>(
    `SELECT EXISTS (
       SELECT 1 FROM chalk_tx WHERE account_id = $1 GROUP BY season HAVING sum(amount) >= $2
     ) AS done`,
    [accountId, target],
  );
  return r.done;
}

export interface BoardRow {
  /** null for a Riser who hasn't linked an account (their row links to the Riser profile). */
  handle: string | null;
  riser_id: number | null;
  display_name: string;
  chalk: number;
  meets: number;
  frame: string | null;
  badge: boolean;
}

/** The Chalkboard: season standings. Ties go to whoever got there first. */
export async function chalkboard(season = currentSeason(), limit = 50) {
  const db = await getDb();
  return db.query<BoardRow>(
    `SELECT handle, riser_id, display_name, frame, badge, chalk, meets FROM (
       SELECT a.handle, NULL::int AS riser_id, a.display_name, s.frame, coalesce(s.badge, false) AS badge, t.chalk, t.last_id,
              (SELECT count(*)::int FROM checkins c JOIN meets m ON m.id = c.meet_id
               WHERE c.account_id = a.id AND m.day BETWEEN $3::date AND $4::date) AS meets
       FROM (
         SELECT account_id, sum(amount)::int AS chalk, max(id) AS last_id
         FROM chalk_tx WHERE season = $1 AND account_id IS NOT NULL GROUP BY account_id HAVING sum(amount) > 0
       ) t
       JOIN accounts a ON a.id = t.account_id
       LEFT JOIN account_style s ON s.account_id = a.id
       UNION ALL
       SELECT NULL::text, p.id, p.name, NULL::text, false, t.chalk, t.last_id, 0
       FROM (
         SELECT puller_id, sum(amount)::int AS chalk, max(id) AS last_id
         FROM chalk_tx WHERE season = $1 AND account_id IS NULL AND puller_id IS NOT NULL GROUP BY puller_id HAVING sum(amount) > 0
       ) t
       JOIN pullers p ON p.id = t.puller_id AND NOT p.hidden
     ) x
     ORDER BY chalk DESC, last_id ASC
     LIMIT $2`,
    [season, limit, seasonStartDay(season), seasonEndDay(season)],
  );
}

/* ─────────── Meets & check-in ─────────── */

export interface Meet {
  id: number;
  day: string;
  code: string;
  is_tournament: boolean;
  open: boolean;
  first_id: number | null;
  second_id: number | null;
  third_id: number | null;
  attendees: number;
}

const MEET_COLS = `m.id, m.day::text AS day, m.code, m.is_tournament, m.open, m.first_id, m.second_id, m.third_id,
  (SELECT count(*)::int FROM checkins c WHERE c.meet_id = m.id) AS attendees`;

/** Today's meet, if an organiser opened check-in today. */
export async function todaysMeet() {
  const db = await getDb();
  const [m] = await db.query<Meet>(`SELECT ${MEET_COLS} FROM meets m WHERE m.day = $1::date`, [sydneyToday()]);
  return m ?? null;
}

export async function listMeets(limit = 24) {
  const db = await getDb();
  return db.query<Meet>(`SELECT ${MEET_COLS} FROM meets m ORDER BY m.day DESC LIMIT $1`, [limit]);
}

export async function meetAttendees(meetId: number) {
  const db = await getDb();
  return db.query<{ id: number; handle: string; display_name: string }>(
    `SELECT a.id, a.handle, a.display_name FROM checkins c JOIN accounts a ON a.id = c.account_id
     WHERE c.meet_id = $1 ORDER BY c.at ASC`,
    [meetId],
  );
}

export async function checkedInToday(accountId: number) {
  const db = await getDb();
  const [r] = await db.query(
    `SELECT 1 FROM checkins c JOIN meets m ON m.id = c.meet_id WHERE c.account_id = $1 AND m.day = $2::date`,
    [accountId, sydneyToday()],
  );
  return !!r;
}

/** Four digits, easy to read out or write on a whiteboard. */
export const newMeetCode = () => String(randomInt(0, 10000)).padStart(4, "0");

/**
 * Records a check-in and awards Chalk: the attendance points, plus the invite bonus to
 * whoever invited this member if it's their first meet. Runs inside a transaction.
 */
export async function recordCheckin(tx: Db, meet: { id: number; day: string }, accountId: number) {
  const season = seasonOf(meet.day);
  const added = await tx.query(
    `INSERT INTO checkins (meet_id, account_id) VALUES ($1, $2) ON CONFLICT DO NOTHING RETURNING meet_id`,
    [meet.id, accountId],
  );
  if (!added.length) return false;
  await awardChalk(tx, accountId, season, CHALK.checkin, `Checked in at the ${meetLabel(meet.day)} meet`, `checkin:${meet.id}`);
  const [first] = await tx.query<{ n: number; invited_by: number | null; display_name: string }>(
    `SELECT (SELECT count(*)::int FROM checkins WHERE account_id = $1) AS n, invited_by, display_name FROM accounts WHERE id = $1`,
    [accountId],
  );
  if (first && first.n === 1 && first.invited_by) {
    await awardChalk(tx, first.invited_by, season, CHALK.invite, `Brought ${first.display_name} to their first meet`, `invite:${accountId}`);
  }
  return true;
}
