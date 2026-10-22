import "server-only";
import { getDb } from "./db";

export interface Supermatch {
  id: number;
  slug: string;
  title: string;
  blurb: string | null;
  arm: "left" | "right";
  a_id: number;
  b_id: number;
  closes_at: string;
  reward: number;
  winner_id: number | null;
  settled_at: string | null;
  a_votes: number;
  b_votes: number;
  pot: number;
  /** Coins staked on each side. */
  a_pot: number;
  b_pot: number;
}

const COLS = `m.id, m.slug, m.title, m.blurb, m.arm, m.a_id, m.b_id, m.closes_at, m.reward, m.winner_id, m.settled_at,
  (SELECT count(*)::int FROM predictions p WHERE p.match_id = m.id AND p.pick_id = m.a_id) AS a_votes,
  (SELECT count(*)::int FROM predictions p WHERE p.match_id = m.id AND p.pick_id = m.b_id) AS b_votes,
  (SELECT coalesce(sum(stake), 0)::int FROM predictions p WHERE p.match_id = m.id) AS pot,
  (SELECT coalesce(sum(stake), 0)::int FROM predictions p WHERE p.match_id = m.id AND p.pick_id = m.a_id) AS a_pot,
  (SELECT coalesce(sum(stake), 0)::int FROM predictions p WHERE p.match_id = m.id AND p.pick_id = m.b_id) AS b_pot`;

/** The supermatch to feature: the next open one, otherwise the most recent. */
export async function featuredSupermatch() {
  const db = await getDb();
  const [open] = await db.query<Supermatch>(
    `SELECT ${COLS} FROM supermatches m WHERE m.settled_at IS NULL ORDER BY m.closes_at ASC LIMIT 1`,
  );
  if (open) return open;
  const [last] = await db.query<Supermatch>(`SELECT ${COLS} FROM supermatches m ORDER BY m.closes_at DESC LIMIT 1`);
  return last ?? null;
}

export async function listSupermatches() {
  const db = await getDb();
  return db.query<Supermatch>(`SELECT ${COLS} FROM supermatches m ORDER BY m.closes_at DESC`);
}

export async function myPick(matchId: number, accountId: number) {
  const db = await getDb();
  const [p] = await db.query<{ pick_id: number; stake: number; odds: number | null }>(
    `SELECT pick_id, stake, odds::float8 AS odds FROM predictions WHERE match_id = $1 AND account_id = $2`,
    [matchId, accountId],
  );
  return p ?? null;
}

export const isOpen = (m: Supermatch) => !m.settled_at && new Date(m.closes_at).getTime() > Date.now();

export interface Backer {
  match_id: number;
  pick_id: number;
  stake: number;
  odds: number | null;
  created_at: string;
  display_name: string;
  handle: string;
}

/** Every pick on every supermatch, for admin HQ, in the order they were placed. */
export async function listBackers() {
  const db = await getDb();
  return db.query<Backer>(
    `SELECT p.match_id, p.pick_id, p.stake, p.odds::float8 AS odds, p.created_at, a.display_name, a.handle
     FROM predictions p JOIN accounts a ON a.id = p.account_id
     ORDER BY p.match_id, p.created_at ASC, p.account_id ASC`,
  );
}

export const armLabel = (m: Pick<Supermatch, "arm">) => (m.arm === "left" ? "Left arm" : "Right arm");

/* ─────────── Prediction record ─────────── */

export interface PickHistory {
  match_id: number;
  title: string;
  arm: "left" | "right";
  closes_at: string;
  settled_at: string | null;
  winner_id: number | null;
  pick_id: number;
  pick_name: string;
  stake: number;
  odds: number | null;
  /** Coins this pick made or lost overall (stake, bonus and payout), straight from the ledger. */
  net: number;
}

export interface PredictionRecord {
  picks: number;
  settled: number;
  correct: number;
  /** 0–100, or null before any result. */
  rate: number | null;
  streak: number;
  bestStreak: number;
  net: number;
  history: PickHistory[];
}

export async function predictionRecord(accountId: number): Promise<PredictionRecord> {
  const db = await getDb();
  const history = await db.query<PickHistory>(
    `SELECT m.id AS match_id, m.title, m.arm, m.closes_at, m.settled_at, m.winner_id, p.pick_id, pu.name AS pick_name,
            p.stake, p.odds::float8 AS odds,
            coalesce((SELECT sum(amount) FROM coin_tx t WHERE t.account_id = p.account_id AND t.ref LIKE 'sm:' || m.id || ':%'), 0)::int AS net
     FROM predictions p
     JOIN supermatches m ON m.id = p.match_id
     JOIN pullers pu ON pu.id = p.pick_id
     WHERE p.account_id = $1
     ORDER BY m.closes_at DESC`,
    [accountId],
  );
  // Results in the order they happened, oldest first, for streaks.
  const results = history
    .filter((h) => h.settled_at)
    .sort((x, y) => new Date(x.settled_at!).getTime() - new Date(y.settled_at!).getTime())
    .map((h) => h.pick_id === h.winner_id);
  let run = 0;
  let bestStreak = 0;
  for (const r of results) {
    run = r ? run + 1 : 0;
    bestStreak = Math.max(bestStreak, run);
  }
  const correct = results.filter(Boolean).length;
  return {
    picks: history.length,
    settled: results.length,
    correct,
    rate: results.length ? Math.round((correct / results.length) * 100) : null,
    streak: run,
    bestStreak,
    net: history.filter((h) => h.settled_at).reduce((s, h) => s + h.net, 0),
    history,
  };
}

export interface Predictor {
  display_name: string;
  handle: string;
  badge: boolean;
  settled: number;
  correct: number;
}

/** Best predictors: most correct calls, then the higher hit rate. */
export async function topPredictors(limit = 5) {
  const db = await getDb();
  return db.query<Predictor>(
    `SELECT a.display_name, a.handle, coalesce(s.badge, false) AS badge,
            count(*)::int AS settled,
            count(*) FILTER (WHERE p.pick_id = m.winner_id)::int AS correct
     FROM predictions p
     JOIN supermatches m ON m.id = p.match_id AND m.settled_at IS NOT NULL
     JOIN accounts a ON a.id = p.account_id
     LEFT JOIN account_style s ON s.account_id = a.id
     GROUP BY a.id, a.display_name, a.handle, s.badge
     ORDER BY correct DESC, (count(*) FILTER (WHERE p.pick_id = m.winner_id))::float / count(*) DESC, a.id ASC
     LIMIT $1`,
    [limit],
  );
}

/** "3/4 · 75%" or null before any settled pick. */
export const recordLabel = (r: { settled: number; correct: number }) =>
  r.settled ? `${r.correct}/${r.settled} · ${Math.round((r.correct / r.settled) * 100)}%` : null;
