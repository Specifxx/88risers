import "server-only";
import { todaysMeet } from "./chalk";
import { getDb } from "./db";

/** auto: on air during supermatches and tournament days. on: always. off: never. */
export type LiveMode = "auto" | "on" | "off";

export interface LiveEvent {
  kind: "supermatch" | "tournament";
  title: string;
  detail: string;
  href: string;
}

export interface LiveState {
  url: string | null;
  mode: LiveMode;
  title: string | null;
  /** A supermatch or tournament happening now, stream or not. */
  event: LiveEvent | null;
  /** Show the live feed instead of the radio. */
  onAir: boolean;
}

/** A supermatch counts as live from 30 minutes before betting closes until 4 hours after (or until settled). */
const BEFORE = 30 * 60_000;
const AFTER = 4 * 3600_000;

export async function liveSettings() {
  const db = await getDb();
  const rows = await db.query<{ key: string; value: string }>(
    `SELECT key, value FROM meta WHERE key IN ('tv_live_url', 'tv_live_mode', 'tv_live_title')`,
  );
  const get = (k: string) => rows.find((r) => r.key === k)?.value || null;
  const mode = get("tv_live_mode");
  return {
    url: get("tv_live_url"),
    title: get("tv_live_title"),
    mode: (mode === "on" || mode === "off" ? mode : "auto") as LiveMode,
  };
}

export async function saveLiveSettings(s: { url: string | null; title: string | null; mode: LiveMode }) {
  const db = await getDb();
  for (const [key, value] of [
    ["tv_live_url", s.url ?? ""],
    ["tv_live_title", s.title ?? ""],
    ["tv_live_mode", s.mode],
  ]) {
    await db.query(`INSERT INTO meta (key, value) VALUES ($1, $2) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`, [key, value]);
  }
}

async function currentEvent(): Promise<LiveEvent | null> {
  const db = await getDb();
  const now = Date.now();
  const [m] = await db.query<{ slug: string; title: string; arm: string; a: string; b: string }>(
    `SELECT m.slug, m.title, m.arm, pa.name AS a, pb.name AS b
     FROM supermatches m JOIN pullers pa ON pa.id = m.a_id JOIN pullers pb ON pb.id = m.b_id
     WHERE m.settled_at IS NULL AND m.closes_at BETWEEN $1 AND $2
     ORDER BY m.closes_at ASC LIMIT 1`,
    [new Date(now - AFTER).toISOString(), new Date(now + BEFORE).toISOString()],
  );
  if (m) {
    return {
      kind: "supermatch",
      title: m.title,
      detail: `${m.a} vs ${m.b} · ${m.arm === "left" ? "Left" : "Right"} arm`,
      href: "/supermatch",
    };
  }
  const meet = await todaysMeet();
  if (meet?.is_tournament) {
    return { kind: "tournament", title: "Tournament day", detail: "The 88 Risers tournament is on today", href: "/events" };
  }
  return null;
}

export async function tvLive(): Promise<LiveState> {
  const [s, event] = await Promise.all([liveSettings(), currentEvent()]);
  const onAir = !!s.url && (s.mode === "on" || (s.mode === "auto" && !!event));
  return { ...s, event, onAir };
}
