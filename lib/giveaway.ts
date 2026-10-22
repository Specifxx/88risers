import "server-only";
import { getDb } from "./db";

/** The current coin giveaway: entries are bought in the reward store (item GIVEAWAY_ITEM). */
export const GIVEAWAY_ITEM = "entry-tee";
export const GIVEAWAY_TITLE = "End of Year Giveaway";
export const GIVEAWAY_PRIZE = "88 Risers Club Tee";
/** New Year's Eve, 6pm Sydney. Admin HQ can change it (stored in meta). */
const DEFAULT_DRAW = "2026-12-31T18:00:00+11:00";
const DRAW_KEY = "giveaway_draw_at";

export interface Giveaway {
  drawAt: string;
  entries: number;
  entrants: number;
  mine: number;
  lastWinner: string | null;
}

export async function getGiveaway(accountId?: number | null): Promise<Giveaway> {
  const db = await getDb();
  const [[setting], [counts], [winner]] = await Promise.all([
    db.query<{ value: string }>(`SELECT value FROM meta WHERE key = $1`, [DRAW_KEY]),
    db.query<{ entries: number; entrants: number; mine: number }>(
      `SELECT count(*)::int AS entries, count(DISTINCT account_id)::int AS entrants,
              count(*) FILTER (WHERE account_id = $2)::int AS mine
       FROM redemptions WHERE item = $1 AND NOT fulfilled`,
      [GIVEAWAY_ITEM, accountId ?? 0],
    ),
    db.query<{ display_name: string }>(
      `SELECT a.display_name FROM redemptions r JOIN accounts a ON a.id = r.account_id
       WHERE r.item = $1 AND r.won ORDER BY r.id DESC LIMIT 1`,
      [GIVEAWAY_ITEM],
    ),
  ]);
  return {
    drawAt: setting?.value ?? DEFAULT_DRAW,
    entries: counts.entries,
    entrants: counts.entrants,
    mine: counts.mine,
    lastWinner: winner?.display_name ?? null,
  };
}

export async function setGiveawayDrawAt(iso: string) {
  const db = await getDb();
  await db.query(`INSERT INTO meta (key, value) VALUES ($1, $2) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`, [DRAW_KEY, iso]);
}
