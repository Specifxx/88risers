import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { Instagram } from "@/components/Icons";
import { LiveRefresh } from "@/components/LiveRefresh";
import { TvPlayer } from "@/components/TvPlayer";
import { TvRadio } from "@/components/TvRadio";
import { listReels } from "@/lib/data";
import { SITE } from "@/lib/site";
import { tvLive } from "@/lib/tv";
import { liveEmbed } from "@/lib/video";

/** Served from cache; regenerated at most once a minute, or immediately after admin edits. */
export const revalidate = 60;

export const metadata: Metadata = {
  title: "88RisersTV",
  description:
    "88RisersTV: live supermatches from the 88 Risers arm wrestling club, 88Risers FM radio in between, and every reel from @88risers_.",
};

export default async function TvPage() {
  const [reels, live] = await Promise.all([listReels(), tvLive()]);
  const feed = live.onAir && live.url ? liveEmbed(live.url) : null;

  return (
    <>
      <section className="page-hero tv-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / 88RisersTV
          </p>
          <h1 className="display tv-logo">
            88<span className="gold-text">Risers</span>
            <span className="tv-badge">TV</span>
          </h1>
          <p className="tv-presented">
            <span>Presented by</span>
            <Image src="/sponsors/supp-station.webp" alt="Supp Station" width={393} height={156} priority />
          </p>
          <p className="lede">
            Supermatches live when they&apos;re on. 88Risers FM in between: pull-day bangers, summer Afro house and phonk.
            Plus every reel from{" "}
            <a href={SITE.instagramUrl} target="_blank" rel="noreferrer">
              @{SITE.instagramHandle}
            </a>
            .
          </p>
        </div>
      </section>

      {/* Re-check once a minute so the screen flips to the live feed when a match starts. */}
      <LiveRefresh seconds={60} />
      <section className="section tv-live-section">
        <div className="wrap">
          {feed ? (
            <div className="tv-live">
              <div className="tv-bezel">
                <div className="tv-screen tv-screen-wide">
                  {feed.kind === "iframe" ? (
                    <iframe
                      src={feed.src}
                      title={live.title ?? "88RisersTV live"}
                      allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
                      allowFullScreen
                    />
                  ) : (
                    <video src={feed.src} controls autoPlay playsInline />
                  )}
                  <span className="tv-osd tv-osd-live" aria-hidden>
                    <i /> Live
                  </span>
                </div>
              </div>
              <div className="tv-live-info">
                <p className="eyebrow">
                  Live now{live.event ? ` · ${live.event.kind === "supermatch" ? "Supermatch" : "Tournament"}` : ""}
                </p>
                <h2 className="tv-title">{live.title || live.event?.title || "88RisersTV live"}</h2>
                {live.event ? <p className="tv-caption">{live.event.detail}</p> : null}
                <p className="tv-presented tv-presented-sm">
                  <span>Presented by</span>
                  <Image src="/sponsors/supp-station.webp" alt="Supp Station" width={393} height={156} />
                </p>
                {live.event?.kind === "supermatch" ? (
                  <Link className="btn btn-primary btn-sm" href={live.event.href}>
                    Back your pick
                  </Link>
                ) : null}
              </div>
            </div>
          ) : (
            <TvRadio event={live.event} />
          )}
        </div>
      </section>

      <section className="section tv-section" style={{ paddingTop: 48 }}>
        <div className="wrap">
          <h2 className="display tv-section-head">
            Replays <span className="gold-text">on demand.</span>
          </h2>
          {reels.length ? (
            <TvPlayer reels={reels} handle={SITE.instagramHandle} />
          ) : (
            <div className="tv-empty">
              <div className="tv-monitor">
                <div className="tv-bezel">
                  <div className="tv-screen tv-screen-off">
                    <div className="tv-static on loop" aria-hidden />
                    <div className="tv-scan" aria-hidden />
                    <p>
                      <b>Off air</b>
                      First broadcast coming soon
                    </p>
                  </div>
                </div>
                <div className="tv-stand" aria-hidden />
              </div>
              <div className="tv-info">
                <p className="eyebrow">Stand by</p>
                <h2 className="tv-title">Tuning in…</h2>
                <p className="tv-caption">
                  The channel goes live as soon as the first reels are added. Until then, catch every clip on Instagram.
                </p>
                <a className="btn btn-primary" href={SITE.instagramUrl} target="_blank" rel="noreferrer">
                  <Instagram /> @{SITE.instagramHandle}
                </a>
              </div>
            </div>
          )}
        </div>
      </section>
    </>
  );
}
