import "server-only";
import { getDb } from "./db";

/**
 * Plays our own Instagram reels directly on 88RisersTV (a real <video>, not Instagram's embed).
 *
 * Uses the Instagram API with Instagram Login: an organiser pastes a long-lived access token for
 * the club's Professional account in admin. Tokens last 60 days; we refresh them automatically
 * (Instagram allows it once a token is a day old), so as long as the site is visited it never lapses.
 * Video URLs from Instagram's CDN expire, so they're looked up again every ~45 minutes.
 */
const GRAPH = "https://graph.instagram.com";
const REFRESH_AFTER_MS = 7 * 86_400_000; // renew weekly (tokens last 60 days)
const STALE_MS = 45 * 60_000;

type Stored = { token: string; username: string; savedAt: number; refreshedAt: number; lastError: string | null };
export type IgStatus = { connected: boolean; username: string | null; savedAt: number | null; refreshedAt: number | null; expiresAt: number | null; lastError: string | null };
export type IgVideo = { src: string; poster: string | null };

async function readStored(): Promise<Stored | null> {
  const db = await getDb();
  const [r] = await db.query<{ value: string }>(`SELECT value FROM meta WHERE key = 'ig_api'`);
  if (!r?.value) return null;
  try {
    return JSON.parse(r.value) as Stored;
  } catch {
    return null;
  }
}
async function writeStored(s: Stored | null) {
  const db = await getDb();
  if (!s) await db.query(`DELETE FROM meta WHERE key = 'ig_api'`);
  else await db.query(`INSERT INTO meta (key, value) VALUES ('ig_api', $1) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`, [JSON.stringify(s)]);
}

/** The reel's shortcode from a pasted link (instagram.com/reel/ABC123/ → ABC123). */
export function igShortcode(url: string): string | null {
  try {
    const u = new URL(url);
    if (!/(^|\.)instagram\.com$/.test(u.hostname)) return null;
    return /^\/(?:[\w.]+\/)?(?:p|reel|reels|tv)\/([\w-]+)/.exec(u.pathname)?.[1] ?? null;
  } catch {
    return null;
  }
}

async function graph<T>(path: string, token: string): Promise<T> {
  const sep = path.includes("?") ? "&" : "?";
  const res = await fetch(`${GRAPH}${path}${sep}access_token=${encodeURIComponent(token)}`, { cache: "no-store", signal: AbortSignal.timeout(8000) });
  const body = (await res.json().catch(() => ({}))) as T & { error?: { message?: string } };
  if (!res.ok || body.error) throw new Error(body.error?.message ?? `Instagram said ${res.status}`);
  return body;
}

/** Saves a token from the Meta dashboard after checking it works. */
export async function connectInstagram(token: string): Promise<{ ok: boolean; message: string }> {
  const t = token.trim();
  if (t.length < 20) return { ok: false, message: "That doesn't look like an access token." };
  try {
    const me = await graph<{ username?: string }>("/me?fields=user_id,username", t);
    const now = Date.now();
    await writeStored({ token: t, username: me.username ?? "unknown", savedAt: now, refreshedAt: now, lastError: null });
    const db = await getDb();
    await db.query(`DELETE FROM meta WHERE key LIKE 'ig_media:%'`);
    return { ok: true, message: `Connected to @${me.username}. Their reels now play directly on 88RisersTV.` };
  } catch (e) {
    return { ok: false, message: `Instagram didn't accept that token: ${e instanceof Error ? e.message : String(e)}` };
  }
}

export async function disconnectInstagram() {
  await writeStored(null);
}

export async function igStatus(): Promise<IgStatus> {
  const s = await readStored();
  if (!s) return { connected: false, username: null, savedAt: null, refreshedAt: null, expiresAt: null, lastError: null };
  return { connected: true, username: s.username, savedAt: s.savedAt, refreshedAt: s.refreshedAt, expiresAt: s.refreshedAt + 60 * 86_400_000, lastError: s.lastError };
}

/** Keeps the token alive: renews it about weekly (it lasts 60 days). */
async function freshToken(): Promise<string | null> {
  const s = await readStored();
  if (!s) return null;
  if (Date.now() - s.refreshedAt > REFRESH_AFTER_MS) {
    try {
      const r = await graph<{ access_token: string }>("/refresh_access_token?grant_type=ig_refresh_token", s.token);
      await writeStored({ ...s, token: r.access_token, refreshedAt: Date.now(), lastError: null });
      return r.access_token;
    } catch (e) {
      await writeStored({ ...s, lastError: `Refresh failed: ${e instanceof Error ? e.message : String(e)}` });
    }
  }
  return s.token;
}

type Media = { media_type?: string; media_url?: string; thumbnail_url?: string; permalink?: string };

/**
 * Direct video files for the given reel links (only reels from the connected account). Anything
 * that can't be resolved is simply left out, and the TV falls back to Instagram's embed.
 */
export async function igVideos(urls: string[]): Promise<Record<string, IgVideo>> {
  const want = [...new Set(urls.map(igShortcode).filter((c): c is string => !!c))];
  if (!want.length) return {};
  const db = await getDb();
  const cached = await db.query<{ key: string; value: string }>(`SELECT key, value FROM meta WHERE key = ANY($1::text[])`, [want.map((c) => `ig_media:${c}`)]);
  const out: Record<string, IgVideo & { at: number }> = {};
  for (const r of cached) {
    try {
      out[r.key.slice(9)] = JSON.parse(r.value);
    } catch {}
  }
  const stale = want.some((c) => !out[c] || Date.now() - out[c].at > STALE_MS);
  if (stale) {
    const token = await freshToken();
    if (token) {
      try {
        // the account's recent media (up to 4 pages of 50), matched to the pasted links by shortcode
        let next: string | null = "/me/media?fields=media_type,media_url,thumbnail_url,permalink&limit=50";
        const left = new Set(want);
        for (let page = 0; next && page < 4 && left.size; page++) {
          const res: { data?: Media[]; paging?: { next?: string } } = await graph(next, token);
          for (const m of res.data ?? []) {
            const code = m.permalink ? igShortcode(m.permalink) : null;
            if (!code || !left.has(code) || m.media_type !== "VIDEO" || !m.media_url) continue;
            left.delete(code);
            const v = { src: m.media_url, poster: m.thumbnail_url ?? null, at: Date.now() };
            out[code] = v;
            await db.query(`INSERT INTO meta (key, value) VALUES ($1, $2) ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value`, [`ig_media:${code}`, JSON.stringify(v)]);
          }
          next = res.paging?.next ? res.paging.next.replace(GRAPH, "").replace(/([?&])access_token=[^&]*&?/, "$1") : null;
        }
      } catch (e) {
        const s = await readStored();
        if (s) await writeStored({ ...s, lastError: `Couldn't load reels: ${e instanceof Error ? e.message : String(e)}` });
      }
    }
  }
  const res: Record<string, IgVideo> = {};
  for (const [code, v] of Object.entries(out)) res[code] = { src: v.src, poster: v.poster };
  return res;
}
