import "server-only";
import { getDb } from "./db";

export interface Supermatch {
  id: number;
  slug: string;
  title: string;
  blurb: string | null;
  a_id: number;
  b_id: number;
  closes_at: string;
  reward: number;
  winner_id: number | null;
  settled_at: string | null;
  a_votes: number;
  b_votes: number;
  pot: number;
}

const COLS = `m.id, m.slug, m.title, m.blurb, m.a_id, m.b_id, m.closes_at, m.reward, m.winner_id, m.settled_at,
  (SELECT count(*)::int FROM predictions p WHERE p.match_id = m.id AND p.pick_id = m.a_id) AS a_votes,
  (SELECT count(*)::int FROM predictions p WHERE p.match_id = m.id AND p.pick_id = m.b_id) AS b_votes,
  (SELECT coalesce(sum(stake), 0)::int FROM predictions p WHERE p.match_id = m.id) AS pot`;

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
  const [p] = await db.query<{ pick_id: number; stake: number }>(
    `SELECT pick_id, stake FROM predictions WHERE match_id = $1 AND account_id = $2`,
    [matchId, accountId],
  );
  return p ?? null;
}

export const isOpen = (m: Supermatch) => !m.settled_at && new Date(m.closes_at).getTime() > Date.now();
