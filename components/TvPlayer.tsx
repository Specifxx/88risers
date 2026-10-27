"use client";

import { useRef, useState } from "react";
import type { Reel } from "@/lib/data";
import { videoEmbed } from "@/lib/video";

const ch = (i: number) => `CH ${String(i + 1).padStart(2, "0")}`;
const fmt = (d: string | null) =>
  d ? new Intl.DateTimeFormat("en-AU", { day: "numeric", month: "short", year: "numeric", timeZone: "UTC" }).format(new Date(d)) : null;

/** 88RisersTV: a featured "monitor", a channel guide, and every episode below. */
export function TvPlayer({ reels, handle }: { reels: Reel[]; handle: string }) {
  const [on, setOn] = useState(0);
  const [flick, setFlick] = useState(0); // bumps to replay the channel-change static
  const stage = useRef<HTMLDivElement>(null);
  const cur = reels[on];
  const embed = cur ? videoEmbed(cur.url) : null;

  const tune = (i: number, scroll = false) => {
    if (i === on) return;
    setOn(i);
    setFlick((f) => f + 1);
    if (scroll) stage.current?.scrollIntoView({ behavior: "smooth", block: "start" });
  };

  return (
    <>
      <div className={`tv-stage${embed && !embed.tall ? " wide" : ""}`} ref={stage}>
        <div className="tv-monitor">
          <div className="tv-bezel">
            <div className="tv-screen">
              {embed ? (
                embed.kind === "iframe" ? (
                  <iframe
                    key={cur.id}
                    src={embed.src}
                    title={cur.title}
                    allow="autoplay; encrypted-media; picture-in-picture; clipboard-write"
                    allowFullScreen
                    loading="lazy"
                  />
                ) : (
                  <video key={cur.id} src={embed.src} controls playsInline preload="metadata" />
                )
              ) : null}
              <div className="tv-scan" aria-hidden />
              <div key={flick} className={flick ? "tv-static on" : "tv-static"} aria-hidden />
              <span className="tv-osd tv-osd-ch" aria-hidden>
                {ch(on)}
              </span>
              <span className="tv-osd tv-osd-live" aria-hidden>
                <i /> On air
              </span>
            </div>
          </div>
          <div className="tv-stand" aria-hidden />
        </div>

        <div className="tv-info">
          <p className="eyebrow">Now playing · {ch(on)}</p>
          <h2 className="tv-title">{cur.title}</h2>
          {cur.caption ? <p className="tv-caption">{cur.caption}</p> : null}
          <p className="tv-meta">
            {fmt(cur.posted_on) ? <span>{fmt(cur.posted_on)}</span> : null}
            <a href={cur.url} target="_blank" rel="noreferrer">
              Watch on {sourceName(cur.url)} ↗
            </a>
          </p>

          {reels.length > 1 ? (
            <div className="tv-guide">
              <p className="tv-guide-head">
                <span>Channel guide</span>
                <span>
                  {on + 1} / {reels.length}
                </span>
              </p>
              <ol>
                {reels.map((r, i) => (
                  <li key={r.id}>
                    <button type="button" onClick={() => tune(i)} aria-current={i === on ? "true" : undefined}>
                      <b>{ch(i)}</b>
                      <span>{r.title}</span>
                      {i === on ? <em>Live</em> : null}
                    </button>
                  </li>
                ))}
              </ol>
              <div className="btn-row">
                <button type="button" className="btn btn-sm btn-ghost" onClick={() => tune((on - 1 + reels.length) % reels.length)}>
                  ‹ Prev
                </button>
                <button type="button" className="btn btn-sm" onClick={() => tune((on + 1) % reels.length)}>
                  Next channel ›
                </button>
              </div>
            </div>
          ) : null}
        </div>
      </div>

      {reels.length > 1 ? (
        <section className="tv-episodes">
          <div className="tv-episodes-head">
            <h2 className="display">
              Every <span className="gold-text">episode.</span>
            </h2>
            <a className="link-arrow" href={`https://www.instagram.com/${handle}/reels/`} target="_blank" rel="noreferrer">
              All reels on Instagram <span>↗</span>
            </a>
          </div>
          <div className="tv-grid">
            {reels.map((r, i) => (
              <button key={r.id} type="button" className="tv-tile" onClick={() => tune(i, true)} aria-current={i === on ? "true" : undefined}>
                <span className="tv-tile-ch">{String(i + 1).padStart(2, "0")}</span>
                <span className="tv-tile-play" aria-hidden>
                  ▶
                </span>
                <span className="tv-tile-body">
                  <b>{r.title}</b>
                  <small>{fmt(r.posted_on) ?? "88RisersTV"}</small>
                </span>
              </button>
            ))}
          </div>
        </section>
      ) : null}
    </>
  );
}

/** Where a video link lives, for the "Watch on …" link. */
function sourceName(url: string) {
  try {
    const h = new URL(url).hostname.replace(/^www\.|^m\./, "");
    if (h === "youtu.be" || h.endsWith("youtube.com")) return "YouTube";
    if (h.endsWith("instagram.com")) return "Instagram";
    if (h.endsWith("tiktok.com")) return "TikTok";
    if (h === "drive.google.com") return "Google Drive";
  } catch {}
  return "the original";
}
