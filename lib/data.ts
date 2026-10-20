import "server-only";
import { getDb, type Db } from "./db";
import { START_ELO, eloAfter } from "./elo";

export interface Puller {
  id: number;
  name: string;
  nickname: string | null;
  title: string | null;
  bio: string | null;
  photo_url: string | null;
  card_url: string | null;
  weight_class: string | null;
  dominant_arm: string | null;
  instagram: string | null;
  is_founder: boolean;
  hidden: boolean;
  elo: number;
  peak_elo: number;
  joined_on: string;
  wins: number;
  losses: number;
  titles: number;
}

export interface MatchView {
  id: number;
  event_id: number | null;
  event_title: string | null;
  event_slug: string | null;
  played_on: string;
  arm: string;
  round: string | null;
  weight_class: string | null;
  score: string | null;
  winner_id: number;
  winner_name: string;
  winner_photo: string | null;
  loser_id: number;
  loser_name: string;
  loser_photo: string | null;
  video_url: string | null;
  is_title_match: boolean;
  notes: string | null;
  winner_elo_before: number | null;
  winner_elo_after: number | null;
  loser_elo_before: number | null;
  loser_elo_after: number | null;
}

export interface ClubEvent {
  id: number;
  slug: string;
  title: string;
  kind: string;
  starts_at: Date;
  ends_at: Date | null;
  venue: string | null;
  address: string | null;
  description: string | null;
  cancelled: boolean;
  match_count?: number;
}

export interface Registration {
  id: number;
  name: string;
  phone: string;
  instagram: string | null;
  photo_id: string | null;
  sms_consent: boolean;
  status: string;
  notes: string | null;
  puller_id: number | null;
  created_at: Date;
}

const PULLER_COLS = `
  p.id, p.name, p.nickname, p.title, p.bio, p.photo_url, p.card_url, p.weight_class,
  p.dominant_arm, p.instagram, p.is_founder, p.hidden, p.elo, p.peak_elo, p.joined_on::text AS joined_on,
  (SELECT count(*)::int FROM matches m WHERE m.winner_id = p.id) AS wins,
  (SELECT count(*)::int FROM matches m WHERE m.loser_id = p.id) AS losses,
  (SELECT count(*)::int FROM matches m WHERE m.winner_id = p.id AND m.is_title_match) AS titles`;

const MATCH_COLS = `
  m.id, m.event_id, e.title AS event_title, e.slug AS event_slug, m.played_on::text AS played_on,
  m.arm, m.round, m.weight_class, m.score, m.winner_id, w.name AS winner_name,
  coalesce(w.photo_url, w.card_url) AS winner_photo, m.loser_id, l.name AS loser_name,
  coalesce(l.photo_url, l.card_url) AS loser_photo, m.video_url, m.is_title_match, m.notes,
  m.winner_elo_before, m.winner_elo_after, m.loser_elo_before, m.loser_elo_after
  FROM matches m
  JOIN pullers w ON w.id = m.winner_id
  JOIN pullers l ON l.id = m.loser_id
  LEFT JOIN events e ON e.id = m.event_id`;

// Public pages are statically cached and regenerated in the background (see
// `revalidate` in each page); admin actions call revalidatePath to refresh them at once.
const db = getDb;

/* ─────────── Pullers ─────────── */

export async function listPullers(opts: { includeHidden?: boolean; q?: string } = {}) {
  const d = await db();
  const where: string[] = [];
  const params: unknown[] = [];
  if (!opts.includeHidden) where.push("NOT p.hidden");
  if (opts.q?.trim()) {
    const q = opts.q.trim().replace(/^#/, "");
    params.push(`%${q}%`);
    const num = /^\d+$/.test(q) ? Number(q) : null;
    if (num !== null) {
      params.push(num);
      where.push(`(p.name ILIKE $1 OR p.nickname ILIKE $1 OR p.id = $2)`);
    } else {
      where.push(`(p.name ILIKE $1 OR p.nickname ILIKE $1)`);
    }
  }
  return d.query<Puller>(
    `SELECT ${PULLER_COLS} FROM pullers p ${where.length ? "WHERE " + where.join(" AND ") : ""} ORDER BY p.id`,
    params,
  );
}

export async function getPuller(id: number, includeHidden = false) {
  const d = await db();
  const [p] = await d.query<Puller>(
    `SELECT ${PULLER_COLS} FROM pullers p WHERE p.id = $1 ${includeHidden ? "" : "AND NOT p.hidden"}`,
    [id],
  );
  return p ?? null;
}

export async function getPullerMatches(id: number) {
  const d = await db();
  return d.query<MatchView>(
    `SELECT ${MATCH_COLS} WHERE m.winner_id = $1 OR m.loser_id = $1 ORDER BY m.played_on DESC, m.id DESC`,
    [id],
  );
}

export async function getLeaderboard(limit = 10) {
  const d = await db();
  return d.query<Puller>(
    `SELECT * FROM (SELECT ${PULLER_COLS} FROM pullers p WHERE NOT p.hidden) x
     WHERE wins + losses > 0 ORDER BY elo DESC, wins DESC, id ASC LIMIT $1`,
    [limit],
  );
}

export async function getClubStats() {
  const d = await db();
  const [s] = await d.query<{ members: number; matches: number; next_id: number; taken: number[] }>(
    `SELECT
       (SELECT count(*)::int FROM pullers WHERE NOT hidden) AS members,
       (SELECT count(*)::int FROM matches) AS matches,
       (SELECT coalesce(max(id), 0)::int + 1 FROM pullers) AS next_id,
       (SELECT coalesce(array_agg(id ORDER BY id), '{}') FROM pullers WHERE NOT hidden) AS taken`,
  );
  return s;
}

/* ─────────── Matches ─────────── */

export async function listRecentMatches(limit = 50) {
  const d = await db();
  return d.query<MatchView>(`SELECT ${MATCH_COLS} ORDER BY m.played_on DESC, m.id DESC LIMIT $1`, [limit]);
}

export async function getEventMatches(eventId: number) {
  const d = await db();
  return d.query<MatchView>(`SELECT ${MATCH_COLS} WHERE m.event_id = $1 ORDER BY m.is_title_match, m.id`, [eventId]);
}

/**
 * Replays every match in chronological order to rebuild ratings. Cheap at club
 * scale and means edits or deletions never leave ratings inconsistent.
 */
export async function recomputeElo(tx: Db) {
  const matches = await tx.query<{ id: number; winner_id: number; loser_id: number }>(
    `SELECT id, winner_id, loser_id FROM matches ORDER BY played_on, id`,
  );
  const elo = new Map<number, number>();
  const peak = new Map<number, number>();
  const get = (id: number) => elo.get(id) ?? START_ELO;
  for (const m of matches) {
    const wb = get(m.winner_id);
    const lb = get(m.loser_id);
    const r = eloAfter(wb, lb);
    elo.set(m.winner_id, r.winner);
    elo.set(m.loser_id, r.loser);
    peak.set(m.winner_id, Math.max(peak.get(m.winner_id) ?? START_ELO, r.winner));
    await tx.query(
      `UPDATE matches SET winner_elo_before=$2, winner_elo_after=$3, loser_elo_before=$4, loser_elo_after=$5 WHERE id=$1`,
      [m.id, wb, r.winner, lb, r.loser],
    );
  }
  await tx.query(`UPDATE pullers SET elo = $1, peak_elo = $1`, [START_ELO]);
  for (const [id, e] of elo) {
    await tx.query(`UPDATE pullers SET elo = $2, peak_elo = $3 WHERE id = $1`, [id, e, peak.get(id) ?? START_ELO]);
  }
}

/* ─────────── Events ─────────── */

const EVENT_COLS = `e.id, e.slug, e.title, e.kind, e.starts_at, e.ends_at, e.venue, e.address, e.description, e.cancelled,
  (SELECT count(*)::int FROM matches m WHERE m.event_id = e.id) AS match_count`;

export async function listEvents(when: "upcoming" | "past" | "all" = "all") {
  const d = await db();
  const where =
    when === "upcoming"
      ? "WHERE coalesce(e.ends_at, e.starts_at + interval '4 hours') >= now()"
      : when === "past"
        ? "WHERE coalesce(e.ends_at, e.starts_at + interval '4 hours') < now()"
        : "";
  const order = when === "upcoming" ? "ASC" : "DESC";
  return d.query<ClubEvent>(`SELECT ${EVENT_COLS} FROM events e ${where} ORDER BY e.starts_at ${order}`);
}

export async function getEventBySlug(slug: string) {
  const d = await db();
  const [e] = await d.query<ClubEvent>(`SELECT ${EVENT_COLS} FROM events e WHERE e.slug = $1`, [slug]);
  return e ?? null;
}

/* ─────────── 88RisersTV ─────────── */

export interface Reel {
  id: number;
  url: string;
  title: string;
  caption: string | null;
  posted_on: string | null;
  sort_order: number;
  hidden: boolean;
}

/** Reels in channel order: lowest sort number first, then newest. */
export async function listReels(opts: { includeHidden?: boolean } = {}) {
  const d = await db();
  return d.query<Reel>(
    `SELECT id, url, title, caption, to_char(posted_on, 'YYYY-MM-DD') AS posted_on, sort_order, hidden
     FROM tv_reels ${opts.includeHidden ? "" : "WHERE NOT hidden"}
     ORDER BY sort_order ASC, posted_on DESC NULLS LAST, id DESC`,
  );
}

/* ─────────── Registrations (admin only) ─────────── */

export async function listRegistrations() {
  const d = await db();
  return d.query<Registration>(
    `SELECT id, name, phone, instagram, photo_id::text AS photo_id, sms_consent, status, notes, puller_id, created_at
     FROM registrations ORDER BY created_at DESC`,
  );
}

export async function getPhoto(id: string) {
  const d = await getDb();
  if (!/^[0-9a-f-]{36}$/i.test(id)) return null;
  const [p] = await d.query<{ mime: string; data: Uint8Array; is_public: boolean }>(
    `SELECT mime, data, is_public FROM photos WHERE id = $1`,
    [id],
  );
  return p ?? null;
}
