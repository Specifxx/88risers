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
