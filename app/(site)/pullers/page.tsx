import type { Metadata } from "next";
import Link from "next/link";
import { Search } from "@/components/Icons";
import { Leaderboard } from "@/components/Leaderboard";
import { PullerSlab } from "@/components/PullerSlab";
import { getClubStats, getLeaderboard, listPullers } from "@/lib/data";
import { TIERS } from "@/lib/elo";

export const revalidate = 60;

export const metadata: Metadata = {
  title: "Riser Database",
  description: "Every 88 Risers puller, their permanent Riser ID, Elo rating, match record and match videos.",
};

export default async function PullersPage({ searchParams }: PageProps<"/pullers">) {
  const { q } = await searchParams;
  const query = typeof q === "string" ? q.slice(0, 60) : "";
  const [pullers, leaders, stats] = await Promise.all([listPullers({ q: query }), getLeaderboard(20), getClubStats()]);

  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / Riser Database
          </p>
          <h1 className="display">
            Riser <span className="gold-text">Database</span>
          </h1>
          <p className="lede">
            {stats.members} Risers · {stats.matches} recorded matches. Every puller keeps their ID for life — look up a
            record, check the rankings, watch the pulls.
          </p>
          <form className="search" role="search">
            <input name="q" type="search" defaultValue={query} placeholder="Name or Riser ID, e.g. 008" aria-label="Search pullers" />
            <button className="btn btn-primary btn-sm" type="submit">
              <Search /> Search
            </button>
          </form>
        </div>
      </section>

      {!query ? (
        <section className="section" id="leaderboard" style={{ paddingBottom: 40 }}>
          <div className="wrap db-band">
            <div>
              <p className="eyebrow">Leaderboard</p>
              <h2 className="display" style={{ fontSize: "clamp(48px, 6vw, 84px)" }}>
                Top of
                <br />
                <span className="gold-text">the table.</span>
              </h2>
              <p className="lede" style={{ marginTop: 18 }}>
                Ratings use Elo: everyone starts at 1000 and moves after every recorded match — beat a higher-rated
                puller and you climb faster. Ratings are provisional for the first five matches.
              </p>
              <div className="profile-tags" style={{ marginTop: 22 }}>
                {[...TIERS].reverse().map((t) => (
                  <span key={t.name} className="pill dim">
                    {t.name} {Number.isFinite(t.min) ? `${t.min}+` : `<950`}
                  </span>
                ))}
              </div>
            </div>
            <Leaderboard rows={leaders} />
          </div>
        </section>
      ) : null}

      <section className="section" style={{ paddingTop: query ? 60 : 40 }}>
        <div className="wrap">
          <div className="panel-title" style={{ marginBottom: 28 }}>
            <span>{query ? `Results for “${query}”` : "All Risers"}</span>
            <small>{pullers.length} FOUND</small>
          </div>
          {pullers.length ? (
            <div className="puller-grid">
              {pullers.map((p) => (
                <PullerSlab key={p.id} p={p} />
              ))}
            </div>
          ) : (
            <div className="empty panel">
              <b>No Riser found</b>
              Try a different name or number. Not in the database yet? <Link href="/join">Register</Link> and pull at our
              next event.
            </div>
          )}
        </div>
      </section>
    </>
  );
}
