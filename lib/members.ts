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
  /** Linked Riser ID, if an organiser has linked this member to their Riser profile. */
  riser_id: number | null;
}

const CARD_COLS = `a.handle, a.display_name,
  coalesce((SELECT sum(amount) FROM coin_tx t WHERE t.account_id = a.id), 0)::int AS coins,
  s.frame, s.title, coalesce(s.badge, false) AS badge,
  (SELECT p.id FROM pullers p WHERE p.account_id = a.id AND NOT p.hidden) AS riser_id`;

/** Name or @username search. */
export async function searchMembers(q: string, limit = 12) {
  const term = q.trim().replace(/^@/, "").slice(0, 40);
  if (term.length < 2) return [];
  const db = await getDb();
  return db.query<MemberCard>(
    `SELECT ${CARD_COLS}
     FROM accounts a LEFT JOIN account_style s ON s.account_id = a.id
     WHERE a.handle ILIKE $1 OR a.display_name ILIKE $1 OR a.handle ILIKE $4
     ORDER BY (a.handle ILIKE $2) DESC, a.display_name ASC
     LIMIT $3`,
    // Usernames can't contain spaces, so "hydraulic press" also tries "hydraulic_press".
    [`%${term}%`, `${term}%`, limit, `%${term.replace(/\s+/g, "\\_")}%`],
  );
}

export interface MemberProfile extends MemberCard {
  id: number;
  created_at: string;
  /** Sign-up order: #1 is the first account ever made. */
  member_no: number;
  items: string[];
  won_giveaway: boolean;
  pinRun: number | null;
  rtp: Partial<Record<RtpLevel, number>>;
  /** The Pin Run lion skin they have equipped (and whether it's gilded gold). */
  lion: string;
  lionGold: boolean;
}

export async function getMember(handle: string): Promise<MemberProfile | null> {
  const db = await getDb();
  const [m] = await db.query<
    MemberCard & { id: number; created_at: string; member_no: number; items: string[] | null; won_giveaway: boolean; pin_run: number | null; lion: string; lion_gold: boolean }
  >(
    `SELECT a.id, a.created_at, ${CARD_COLS},
            (SELECT count(*)::int FROM accounts b WHERE b.id <= a.id) AS member_no,
            (SELECT array_agg(DISTINCT r.item) FROM redemptions r WHERE r.account_id = a.id) AS items,
            EXISTS (SELECT 1 FROM redemptions r WHERE r.account_id = a.id AND r.won) AS won_giveaway,
            (SELECT best FROM game_scores g WHERE g.account_id = a.id) AS pin_run,
            coalesce((SELECT w.skin FROM pinrun_wallet w WHERE w.account_id = a.id), 'stone') AS lion,
            coalesce((SELECT w.skin = ANY(w.gold) FROM pinrun_wallet w WHERE w.account_id = a.id), false) AS lion_gold
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
  const { pin_run, items, lion_gold, ...rest } = m;
  return { ...rest, items: items ?? [], pinRun: pin_run, lionGold: lion_gold, rtp };
}

/** The current handle for a member who has since changed it, or null. */
export async function currentHandleFor(oldHandle: string) {
  const db = await getDb();
  const [r] = await db.query<{ handle: string }>(
    `SELECT a.handle FROM handle_history h JOIN accounts a ON a.id = h.account_id WHERE h.old_handle = $1`,
    [oldHandle],
  );
  return r?.handle ?? null;
}
