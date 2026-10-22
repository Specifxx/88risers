import type { Metadata } from "next";
import Link from "next/link";
import { Leaderboard } from "@/components/Leaderboard";
import { PullerSearch } from "@/components/PullerSearch";
import { PullerSlab } from "@/components/PullerSlab";
import { chalkboard, chalkSettings, currentSeason } from "@/lib/chalk";
import { getClubStats, listPullers } from "@/lib/data";
import { formatId } from "@/lib/site";

export const revalidate = 60;

export const metadata: Metadata = {
  title: "Riser Database",
  description: "Every 88 Risers puller, their permanent Riser ID, match record and match videos, plus the season Chalkboard.",
};

export default async function PullersPage() {
  const [pullers, leaders, stats, settings] = await Promise.all([listPullers(), chalkboard(currentSeason(), 10), getClubStats(), chalkSettings()]);

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
              <p className="eyebrow">{currentSeason()} season</p>
              <h2 className="display" style={{ fontSize: "clamp(48px, 6vw, 84px)" }}>
                The
                <br />
                <span className="gold-text">Chalkboard.</span>
              </h2>
              <p className="lede" style={{ marginTop: 18 }}>
                Members earn Chalk by checking in at meets, bringing friends, placing at tournaments and pulling in
                supermatches. Hit {settings.target} to complete the Lift; top of the board on 31 December is crowned Top Riser.
              </p>
              <Link className="link-arrow" href="/chalk" style={{ marginTop: 18, display: "inline-flex" }}>
                Full standings &amp; how it works <span>→</span>
              </Link>
            </div>
            <Leaderboard rows={leaders} target={settings.target} />
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
