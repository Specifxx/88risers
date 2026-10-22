import "server-only";
import { RTP_GAME, RTP_LEVELS, type RtpLevel } from "./arcade";
import { getDb } from "./db";

/** Public view of a member account: no private details, just what's already on leaderboards. */
export interface MemberCard {
  handle: string;
  display_name: string;
  coins: number;
  frame: string | null;
  title: string | null;
  badge: boolean;
}

const CARD_COLS = `a.handle, a.display_name,
  coalesce((SELECT sum(amount) FROM coin_tx t WHERE t.account_id = a.id), 0)::int AS coins,
  s.frame, s.title, coalesce(s.badge, false) AS badge`;

/** Name or @username search. */
export async function searchMembers(q: string, limit = 12) {
  const term = q.trim().replace(/^@/, "").slice(0, 40);
  if (term.length < 2) return [];
  const db = await getDb();
  return db.query<MemberCard>(
    `SELECT ${CARD_COLS}
     FROM accounts a LEFT JOIN account_style s ON s.account_id = a.id
     WHERE a.handle ILIKE $1 OR a.display_name ILIKE $1
     ORDER BY (a.handle ILIKE $2) DESC, a.display_name ASC
     LIMIT $3`,
    [`%${term}%`, `${term}%`, limit],
  );
}

export interface MemberProfile extends MemberCard {
  id: number;
  created_at: string;
  pinRun: number | null;
  rtp: Partial<Record<RtpLevel, number>>;
}

export async function getMember(handle: string): Promise<MemberProfile | null> {
  const db = await getDb();
  const [m] = await db.query<MemberCard & { id: number; created_at: string; pin_run: number | null }>(
    `SELECT a.id, a.created_at, ${CARD_COLS},
            (SELECT best FROM game_scores g WHERE g.account_id = a.id) AS pin_run
     FROM accounts a LEFT JOIN account_style s ON s.account_id = a.id
     WHERE a.handle = $1`,
    [handle.toLowerCase()],
  );
  if (!m) return null;
  const rtpRows = await db.query<{ level: RtpLevel; best: number }>(
    `SELECT level, best FROM arcade_scores WHERE account_id = $1 AND game = $2`,
    [m.id, RTP_GAME],
  );
  const rtp: Partial<Record<RtpLevel, number>> = {};
  for (const r of rtpRows) if (RTP_LEVELS.some((l) => l.id === r.level)) rtp[r.level] = r.best;
  const { pin_run, ...rest } = m;
  return { ...rest, pinRun: pin_run, rtp };
}
