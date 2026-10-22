import "server-only";
import { CHALK, awardChalk } from "./chalk";
import type { Db } from "./db";
import { getDb } from "./db";

/**
 * Competition results: placings at outside comps (and our own), shown on Riser profiles.
 * A podium (1st–3rd) earns the Riser's linked member account Chalk for that season.
 */
export interface CompResult {
  id: number;
  puller_id: number;
  event: string;
  division: string | null;
  place: number;
  played_on: string | null;
  season: number;
  notes: string | null;
}

const COLS = `id, puller_id, event, division, place, played_on::text AS played_on, season, notes`;

export async function resultsFor(pullerId: number) {
  const db = await getDb();
  return db.query<CompResult>(
    `SELECT ${COLS} FROM comp_results WHERE puller_id = $1 ORDER BY season DESC, played_on DESC NULLS LAST, id DESC`,
    [pullerId],
  );
}

export async function allResults() {
  const db = await getDb();
  return db.query<CompResult>(`SELECT ${COLS} FROM comp_results ORDER BY season DESC, id DESC`);
}

export const placeLabel = (n: number) => (n === 1 ? "1st" : n === 2 ? "2nd" : n === 3 ? "3rd" : `${n}th`);
export const medal = (n: number) => (n === 1 ? "🥇" : n === 2 ? "🥈" : n === 3 ? "🥉" : "🎖️");
export const podiumChalk = (place: number) => (place >= 1 && place <= 3 ? CHALK.podium[place - 1] : 0);

/** Pays podium Chalk for any of this Riser's results to their linked account (once each). */
export async function awardResultsChalk(db: Db, pullerId: number) {
  const [p] = await db.query<{ account_id: number | null }>(`SELECT account_id FROM pullers WHERE id = $1`, [pullerId]);
  if (!p?.account_id) return 0;
  const rows = await db.query<CompResult>(`SELECT ${COLS} FROM comp_results WHERE puller_id = $1 AND place BETWEEN 1 AND 3`, [pullerId]);
  let n = 0;
  for (const r of rows) {
    const label = `${placeLabel(r.place)} at ${r.event}${r.division ? ` (${r.division})` : ""}`;
    if (await awardChalk(db, p.account_id, r.season, podiumChalk(r.place), label, `result:${r.id}`)) n++;
  }
  return n;
}
