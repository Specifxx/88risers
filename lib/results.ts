import "server-only";
import { CHALK, awardChalk, awardRiserChalk, claimRiserChalk, currentSeason, seasonOf } from "./chalk";
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
  if (!p) return 0;
  // linked: anything the Riser profile was holding moves to the account first
  if (p.account_id) await claimRiserChalk(db, pullerId, p.account_id);
  const give = (season: number, amount: number, label: string, ref: string) =>
    p.account_id ? awardChalk(db, p.account_id, season, amount, label, ref) : awardRiserChalk(db, pullerId, season, amount, label, ref);
  const rows = await db.query<CompResult>(`SELECT ${COLS} FROM comp_results WHERE puller_id = $1 AND place BETWEEN 1 AND 3`, [pullerId]);
  let n = 0;
  for (const r of rows) {
    const label = `${placeLabel(r.place)} at ${r.event}${r.division ? ` (${r.division})` : ""}`;
    if (await give(r.season, podiumChalk(r.place), label, `result:${r.id}`)) n++;
  }
  // Supermatches recorded as matches (round "Supermatch …"): Chalk for pulling, more for winning.
  // (Supermatches run through the picks system pay their Chalk when settled, so they aren't recorded twice.)
  const sms = await db.query<{ id: number; won: boolean; played_on: string | null; round: string }>(
    `SELECT id, winner_id = $1 AS won, played_on::text AS played_on, round FROM matches
     WHERE (winner_id = $1 OR loser_id = $1) AND round ILIKE 'Supermatch%'`,
    [pullerId],
  );
  for (const m of sms) {
    const amount = CHALK.supermatch + (m.won ? CHALK.supermatchWin : 0);
    const label = `${m.won ? "Won" : "Pulled in"} ${m.round}`;
    if (await give(m.played_on ? seasonOf(m.played_on) : currentSeason(), amount, label, `match-sm:${m.id}`)) n++;
  }
  return n;
}
