/** Turn a pasted video link into something embeddable. */
export function videoEmbed(url: string): { src: string; kind: "iframe" | "video"; tall: boolean } | null {
  let u: URL;
  try {
    u = new URL(url);
  } catch {
    return null;
  }
  const host = u.hostname.replace(/^www\.|^m\./, "");
  if (host === "youtu.be") return { src: `https://www.youtube-nocookie.com/embed/${u.pathname.slice(1)}`, kind: "iframe", tall: false };
  if (host === "youtube.com") {
    const shorts = /^\/shorts\/([\w-]+)/.exec(u.pathname);
    if (shorts) return { src: `https://www.youtube-nocookie.com/embed/${shorts[1]}`, kind: "iframe", tall: true };
    const v = u.searchParams.get("v");
    if (v) return { src: `https://www.youtube-nocookie.com/embed/${v}`, kind: "iframe", tall: false };
  }
  if (host === "instagram.com") {
    const m = /^\/(?:[\w.]+\/)?(p|reel|reels|tv)\/([\w-]+)/.exec(u.pathname);
    if (m) return { src: `https://www.instagram.com/${m[1] === "reels" ? "reel" : m[1]}/${m[2]}/embed`, kind: "iframe", tall: true };
  }
  if (host === "tiktok.com") {
    const m = /\/video\/(\d+)/.exec(u.pathname);
    if (m) return { src: `https://www.tiktok.com/embed/v2/${m[1]}`, kind: "iframe", tall: true };
  }
  if (host === "drive.google.com") {
    const m = /\/file\/d\/([\w-]+)/.exec(u.pathname);
    if (m) return { src: `https://drive.google.com/file/d/${m[1]}/preview`, kind: "iframe", tall: false };
  }
  if (/\.(mp4|webm|mov)$/i.test(u.pathname)) return { src: url, kind: "video", tall: false };
  return null;
}

/**
 * Turn a live stream link into an embed: YouTube (live video, /live/ID, or a channel's
 * /channel/UC…/live page), Twitch, Kick, or a direct video/HLS stream. Falls back to videoEmbed.
 */
export function liveEmbed(url: string, hosts: string[] = ["88risers.com", "www.88risers.com"]): { src: string; kind: "iframe" | "video" } | null {
  let u: URL;
  try {
    u = new URL(url);
  } catch {
    return null;
  }
  const host = u.hostname.replace(/^www\.|^m\./, "");
  if (host === "youtube.com") {
    const live = /^\/live\/([\w-]+)/.exec(u.pathname);
    if (live) return { src: `https://www.youtube-nocookie.com/embed/${live[1]}?autoplay=1`, kind: "iframe" };
    const chan = /^\/channel\/(UC[\w-]+)/.exec(u.pathname);
    if (chan) return { src: `https://www.youtube.com/embed/live_stream?channel=${chan[1]}&autoplay=1`, kind: "iframe" };
  }
  if (host === "twitch.tv") {
    const c = u.pathname.split("/").filter(Boolean)[0];
    if (c) return { src: `https://player.twitch.tv/?channel=${c}&${hosts.map((h) => `parent=${h}`).join("&")}`, kind: "iframe" };
  }
  if (host === "kick.com") {
    const c = u.pathname.split("/").filter(Boolean)[0];
    if (c) return { src: `https://player.kick.com/${c}`, kind: "iframe" };
  }
  if (/\.m3u8$/i.test(u.pathname)) return { src: url, kind: "video" };
  const v = videoEmbed(url);
  return v ? { src: v.kind === "iframe" && v.src.includes("youtube") ? `${v.src}?autoplay=1` : v.src, kind: v.kind } : null;
}
