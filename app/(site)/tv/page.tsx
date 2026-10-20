import type { Metadata } from "next";
import Link from "next/link";
import { Instagram } from "@/components/Icons";
import { TvPlayer } from "@/components/TvPlayer";
import { listReels } from "@/lib/data";
import { SITE } from "@/lib/site";

/** Served from cache; regenerated at most once a minute, or immediately after admin edits. */
export const revalidate = 60;

export const metadata: Metadata = {
  title: "88RisersTV",
  description: "88RisersTV: pulls, upsets and table-side chaos from the 88 Risers arm wrestling club, straight from @88risers_.",
};

export default async function TvPage() {
  const reels = await listReels();

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
          <p className="lede">
            Pulls, upsets and table-side chaos. Every reel from{" "}
            <a href={SITE.instagramUrl} target="_blank" rel="noreferrer">
              @{SITE.instagramHandle}
            </a>
            , one channel.
          </p>
        </div>
      </section>

      <section className="section tv-section" style={{ paddingTop: 48 }}>
        <div className="wrap">
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
