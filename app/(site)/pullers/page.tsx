import type { Metadata } from "next";
import Link from "next/link";
import { Leaderboard } from "@/components/Leaderboard";
import { PullerSearch } from "@/components/PullerSearch";
import { PullerSlab } from "@/components/PullerSlab";
import { getClubStats, getLeaderboard, listPullers } from "@/lib/data";
import { TIERS } from "@/lib/elo";
import { formatId } from "@/lib/site";

export const revalidate = 60;

export const metadata: Metadata = {
  title: "Riser Database",
  description: "Every 88 Risers puller, their permanent Riser ID, Elo rating, match record and match videos.",
};

export default async function PullersPage() {
  const [pullers, leaders, stats] = await Promise.all([listPullers(), getLeaderboard(20), getClubStats()]);

  return (
    <PullerSearch
      hero={
        <>
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
        </>
      }
      board={
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
      }
      entries={pullers.map((p) => ({
        id: p.id,
        text: [p.name, p.nickname ?? "", formatId(p.id)].join(" ").toLowerCase(),
        node: <PullerSlab p={p} />,
      }))}
    />
  );
}
