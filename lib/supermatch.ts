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

/** Every pick on every supermatch, for admin HQ. Biggest stakes first. */
export async function listBackers() {
  const db = await getDb();
  return db.query<Backer>(
    `SELECT p.match_id, p.pick_id, p.stake, p.odds::float8 AS odds, p.created_at, a.display_name, a.handle
     FROM predictions p JOIN accounts a ON a.id = p.account_id
     ORDER BY p.match_id, p.stake DESC, p.created_at ASC`,
  );
}

export const armLabel = (m: Pick<Supermatch, "arm">) => (m.arm === "left" ? "Left arm" : "Right arm");
