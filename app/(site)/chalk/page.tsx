import type { Metadata } from "next";
import Link from "next/link";
import { ChalkLift } from "@/components/ChalkLift";
import { CheckInBox } from "@/components/CheckInBox";
import { currentAccount } from "@/lib/auth";
import { CHALK, chalkboard, chalkOf, chalkSettings, checkedInToday, currentSeason, seasonEnd, todaysMeet } from "@/lib/chalk";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "The Chalkboard",
  description: "Chalk: the 88 Risers season table. Show up, compete, complete the Lift and chase Top Riser.",
};

export default async function ChalkPage() {
  const season = currentSeason();
  const [me, settings, board, meet] = await Promise.all([currentAccount(), chalkSettings(), chalkboard(season, 50), todaysMeet()]);
  const [mine, here] = await Promise.all([me ? chalkOf(me.id, season) : 0, me && meet ? checkedInToday(me.id) : false]);
  const days = Math.max(0, Math.ceil((seasonEnd(season).getTime() - Date.now()) / 86400000));
  const lifted = board.filter((r) => r.chalk >= settings.target).length;

  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / The Chalkboard
          </p>
          <p className="eyebrow">{season} season · {days} days left</p>
          <h1 className="display">
            The <span className="gold-text">Chalkboard.</span>
          </h1>
          <p className="lede">
            Chalk up by showing up. Hit {settings.target} Chalk this season to complete the Lift, and whoever tops the board on
            31 December is crowned <b>Top Riser</b>.
          </p>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 32 }}>
        <div className="wrap">
          {meet?.open ? (
            <div style={{ marginBottom: 28 }}>
              <CheckInBox loggedIn={!!me} already={here} points={CHALK.checkin} />
            </div>
          ) : null}

          <div className="chalk-grid">
            <div className="panel">
              <h2 className="panel-title">{me ? "Your Lift" : "The Lift"}</h2>
              <ChalkLift chalk={me ? mine : Math.round(settings.target * 0.55)} target={settings.target} />
              <p className="muted" style={{ marginTop: 14 }}>
                {me ? (
                  mine >= settings.target ? (
                    <>
                      Lift complete! You&apos;ve earned: <b className="gold">{settings.liftPrize}</b>.
                    </>
                  ) : (
                    <>
                      {settings.target - mine} Chalk to go. Complete the Lift to earn: <b className="gold">{settings.liftPrize}</b>.
                    </>
                  )
                ) : (
                  <>
                    Every member has a Lift that rises as they earn Chalk.{" "}
                    <Link href="/account?next=/chalk">Create a free account</Link> to start yours.
                  </>
                )}
              </p>
            </div>

            <div className="panel">
              <h2 className="panel-title">How to earn Chalk</h2>
              <ul className="ledger chalk-rules">
                <li>
                  <span>Check in at a meet</span>
                  <b>+{CHALK.checkin}</b>
                </li>
                <li>
                  <span>Someone you invited comes to their first meet</span>
                  <b>+{CHALK.invite}</b>
                </li>
                <li>
                  <span>Tournament 1st · 2nd · 3rd</span>
                  <b>+{CHALK.podium.join(" · ")}</b>
                </li>
                <li>
                  <span>Pull in a club supermatch · win it</span>
                  <b>
                    +{CHALK.supermatch} · +{CHALK.supermatch + CHALK.supermatchWin}
                  </b>
                </li>
              </ul>
              <div className="chalk-prizes">
                <div>
                  <span>Complete the Lift · {settings.target} Chalk</span>
                  <b>{settings.liftPrize}</b>
                  <small>Everyone who gets there.</small>
                </div>
                <div className="top">
                  <span>Top Riser · #1 on 31 December</span>
                  <b>{settings.topPrize}</b>
                  <small>Ties go to whoever got there first.</small>
                </div>
              </div>
              {me ? (
                <p className="fine" style={{ marginTop: 14 }}>
                  Invite a friend: they put <b>@{me.handle}</b> as &ldquo;Invited by&rdquo; when they sign up.
                </p>
              ) : null}
            </div>
          </div>

          <div className="panel" style={{ marginTop: 24 }}>
            <h2 className="panel-title">
              {season} standings
              <small>{lifted ? `${lifted} completed the Lift` : ""}</small>
            </h2>
            {board.length ? (
              <table className="chalk-table">
                <thead>
                  <tr>
                    <th>#</th>
                    <th>Member</th>
                    <th className="num">Meets</th>
                    <th className="num">Chalk</th>
                    <th className="num">Lift</th>
                  </tr>
                </thead>
                <tbody>
                  {board.map((r, i) => (
                    <tr key={r.handle} className={me?.handle === r.handle ? "me" : undefined}>
                      <td className="rank">{i === 0 ? "♛" : i + 1}</td>
                      <td>
                        <Link href={`/members/${r.handle}`}>{r.display_name}</Link>
                        {r.badge ? <i className="cl-lion" aria-label="Lion badge" /> : null}
                        {i === 0 ? <span className="pill">Top Riser so far</span> : null}
                      </td>
                      <td className="num">{r.meets}</td>
                      <td className="num">
                        <b>{r.chalk}</b>
                      </td>
                      <td className="num">{r.chalk >= settings.target ? "✓" : `${Math.round((r.chalk / settings.target) * 100)}%`}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <p className="muted">No Chalk yet this season. Check in at the next meet to get on the board.</p>
            )}
          </div>
        </div>
      </section>
    </>
  );
}
