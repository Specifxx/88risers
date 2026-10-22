import "server-only";
import { getDb } from "./db";

/** Race to the Pin (public/arcade). Scores are per difficulty; they aren't comparable across levels. */
export const RTP_GAME = "race-to-the-pin";
export const RTP_LEVELS = [
  { id: "rookie", name: "Rookie" },
  { id: "club", name: "Club" },
  { id: "elite", name: "Elite" },
  { id: "kelvinator", name: "Kelvinator" },
] as const;
export type RtpLevel = (typeof RTP_LEVELS)[number]["id"];
/** 24 checks × 250 max per check + speed bonus is ~6,600; anything above is not a real score. */
export const RTP_MAX_SCORE = 7000;

export const isRtpLevel = (l: string): l is RtpLevel => RTP_LEVELS.some((x) => x.id === l);

export interface ArcadeRow {
  level: RtpLevel;
  display_name: string;
  handle: string;
  best: number;
}

/** Top `perLevel` scores for every difficulty. */
export async function rtpLeaders(perLevel = 5) {
  const db = await getDb();
  const rows = await db.query<ArcadeRow>(
    `SELECT level, display_name, handle, best FROM (
       SELECT s.level, a.display_name, a.handle, s.best,
              row_number() OVER (PARTITION BY s.level ORDER BY s.best DESC, s.updated_at ASC) AS rk
       FROM arcade_scores s JOIN accounts a ON a.id = s.account_id
       WHERE s.game = $1
     ) t WHERE rk <= $2 ORDER BY level, rk`,
    [RTP_GAME, perLevel],
  );
  return Object.fromEntries(RTP_LEVELS.map((l) => [l.id, rows.filter((r) => r.level === l.id)])) as Record<RtpLevel, ArcadeRow[]>;
}

/** This account's best per difficulty. */
export async function rtpMine(accountId: number) {
  const db = await getDb();
  const rows = await db.query<{ level: RtpLevel; best: number }>(
    `SELECT level, best FROM arcade_scores WHERE account_id = $1 AND game = $2`,
    [accountId, RTP_GAME],
  );
  return Object.fromEntries(rows.map((r) => [r.level, r.best])) as Partial<Record<RtpLevel, number>>;
}
