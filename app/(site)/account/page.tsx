import type { Metadata } from "next";
import Link from "next/link";
import { AccountForms } from "@/components/AccountForms";
import { AchievementWall } from "@/components/AchievementWall";
import { RiserPass } from "@/components/RiserPass";
import { earnedAchievements } from "@/lib/achievements";
import { getMember } from "@/lib/members";
import { ChalkLift } from "@/components/ChalkLift";
import { LionShowcase } from "@/components/LionShowcase";
import { getWallet } from "@/lib/pinrun-db";
import { CheckInBox } from "@/components/CheckInBox";
import { CHALK, chalkHistory, chalkOf, chalkSettings, checkedInToday, liftCompletedEver, todaysMeet } from "@/lib/chalk";
import { currentAccount } from "@/lib/auth";
import { STORE, coinHistory, itemById, redemptionsOf, styleOf } from "@/lib/coins";
import { fmtOdds } from "@/lib/odds";
import { fmtShortDate } from "@/lib/schedule";
import { predictionRecord, recordLabel } from "@/lib/supermatch";
import { equipFrame, logOut } from "./actions";

export const metadata: Metadata = {
  title: "Account",
  description: "Your 88 Risers account: coins, supermatch picks and rewards.",
  robots: { index: false },
};

export default async function AccountPage({ searchParams }: PageProps<"/account">) {
  const sp = await searchParams;
  const next = typeof sp.next === "string" ? sp.next : "/account";
  const me = await currentAccount();

  if (!me) {
    return (
      <>
        <section className="page-hero">
          <div className="wrap">
            <p className="crumbs">
              <Link href="/">Home</Link> / Account
            </p>
            <h1 className="display">
              Your <span className="gold-text">pass.</span>
            </h1>
            <p className="lede">
              Make supermatch picks, stack 88Risers coins, play Pin Run and unlock rewards. Free, and separate from
              registering for meets.
            </p>
          </div>
        </section>
        <section className="section" style={{ paddingTop: 40 }}>
          <div className="wrap">
            <AccountForms next={next} start={sp.mode === "login" ? "login" : "signup"} />
          </div>
        </section>
      </>
    );
  }

  const [history, style, items, rec, profile, wallet] = await Promise.all([
    coinHistory(me.id),
    styleOf(me.id),
    redemptionsOf(me.id),
    predictionRecord(me.id),
    getMember(me.handle),
    getWallet(me.id),
  ]);
  const [settings, chalk, chalkLog, meet] = await Promise.all([chalkSettings(), chalkOf(me.id), chalkHistory(me.id), todaysMeet()]);
  const [here, liftDone] = await Promise.all([meet ? checkedInToday(me.id) : false, liftCompletedEver(me.id, settings.target)]);
  const earned = profile
    ? earnedAchievements({
        memberNo: profile.member_no,
        coins: profile.coins,
        rec,
        pinRun: profile.pinRun,
        rtp: profile.rtp,
        items: profile.items,
        wonGiveaway: profile.won_giveaway,
        liftDone,
      })
    : new Set<string>();
  const ownedFrames = STORE.filter((i) => i.kind === "frame" && items.some((r) => r.item === i.id));

  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / Account
          </p>
          <h1 className="display">
            G&apos;day, <span className="gold-text">{me.display_name.split(" ")[0]}.</span>
          </h1>
          <div className="btn-row" style={{ marginTop: 24 }}>
            <Link className="btn btn-primary" href="/supermatch">
              Make your pick
            </Link>
            <Link className="btn" href="/rewards">
              Spend coins
            </Link>
            <Link className="btn btn-ghost" href="/play">
              Play Pin Run
            </Link>
            <Link className="btn btn-ghost" href={`/members/${me.handle}`}>
              Your public profile
            </Link>
            {profile?.riser_id ? (
              <Link className="btn btn-ghost" href={`/pullers/${profile.riser_id}`}>
                Your Riser profile
              </Link>
            ) : null}
            <form action={logOut}>
              <button className="btn btn-ghost">Log out</button>
            </form>
          </div>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 48 }}>
        <div className="wrap account-grid">
          <div>
            <RiserPass name={me.display_name} handle={me.handle} coins={me.coins} style={style} record={recordLabel(rec)} />
            {ownedFrames.length ? (
              <form action={equipFrame} className="frame-pick">
                <label htmlFor="frame">Frame</label>
                <select id="frame" name="frame" defaultValue={style.frame ?? ""}>
                  <option value="">None</option>
                  {ownedFrames.map((f) => (
                    <option key={f.id} value={f.style}>
                      {f.name}
                    </option>
                  ))}
                </select>
                <button className="btn btn-sm">Equip</button>
              </form>
            ) : null}
            <div style={{ marginTop: 20 }}>
              <LionShowcase skin={profile?.lion ?? "stone"} title="Your lion" mine templeCoins={wallet.coins} />
            </div>
          </div>

          <div className="account-cols">
            {meet?.open ? <CheckInBox loggedIn already={here} points={CHALK.checkin} /> : null}
            <div className="panel">
              <h2 className="panel-title">
                Your Lift
                <small>
                  <Link href="/chalk">The Chalkboard →</Link>
                </small>
              </h2>
              <div className="lift-panel">
                <ChalkLift chalk={chalk} target={settings.target} />
                <div>
                  <p className="muted" style={{ marginTop: 0 }}>
                    {chalk >= settings.target ? (
                      <>
                        Lift complete! You&apos;ve earned <b className="gold">{settings.liftPrize}</b>.
                      </>
                    ) : (
                      <>
                        {settings.target - chalk} Chalk to complete the Lift and earn <b className="gold">{settings.liftPrize}</b>.
                      </>
                    )}
                  </p>
                  {chalkLog.length ? (
                    <ul className="ledger">
                      {chalkLog.slice(0, 6).map((h, i) => (
                        <li key={i}>
                          <span>{h.reason}</span>
                          <b className={h.amount < 0 ? "neg" : "pos"}>
                            {h.amount > 0 ? "+" : ""}
                            {h.amount}
                          </b>
                        </li>
                      ))}
                    </ul>
                  ) : (
                    <p className="muted">Check in at your next meet for your first Chalk.</p>
                  )}
                  <p className="fine">
                    Invite friends: they enter <b>@{me.handle}</b> as &ldquo;Invited by&rdquo; when signing up, and you get +
                    {CHALK.invite} when they come to their first meet.
                  </p>
                </div>
              </div>
            </div>
            <AchievementWall earned={earned} title="Your achievements" />
            <div className="panel picks-panel">
              <h2 className="panel-title">Supermatch picks</h2>
              <div className="pick-stats">
                <div>
                  <b>{rec.settled ? `${rec.correct}/${rec.settled}` : "–"}</b>
                  <span>correct</span>
                </div>
                <div>
                  <b>{rec.rate === null ? "–" : `${rec.rate}%`}</b>
                  <span>hit rate</span>
                </div>
                <div>
                  <b>{rec.streak}</b>
                  <span>streak{rec.bestStreak > rec.streak ? ` · best ${rec.bestStreak}` : ""}</span>
                </div>
                <div>
                  <b className={rec.net < 0 ? "neg" : rec.net > 0 ? "pos" : undefined}>
                    {rec.net > 0 ? "+" : ""}
                    {rec.net}
                  </b>
                  <span>coins from picks</span>
                </div>
              </div>
              {rec.history.length ? (
                <ul className="ledger">
                  {rec.history.map((h) => {
                    const status = !h.settled_at ? "pending" : h.pick_id === h.winner_id ? "won" : "lost";
                    return (
                      <li key={h.match_id}>
                        <span>
                          {h.title} · {h.arm === "left" ? "left arm" : "right arm"}
                          <br />
                          <small>
                            Picked {h.pick_name}
                            {h.stake ? ` · ${h.stake} at ${fmtOdds(h.odds ?? 2)}` : ""}
                          </small>
                        </span>
                        <small className={`pick-${status}`}>{status === "pending" ? "Pending" : status === "won" ? "Called it" : "Missed"}</small>
                        {status === "pending" ? (
                          <b>{h.stake ? `−${h.stake}` : "0"}</b>
                        ) : (
                          <b className={h.net < 0 ? "neg" : "pos"}>
                            {h.net > 0 ? "+" : ""}
                            {h.net}
                          </b>
                        )}
                      </li>
                    );
                  })}
                </ul>
              ) : (
                <p className="muted">
                  No picks yet. <Link href="/supermatch">Make your first call →</Link>
                </p>
              )}
            </div>
            <div className="panel">
              <h2 className="panel-title">Coin history</h2>
              <ul className="ledger">
                {history.map((h, i) => (
                  <li key={i}>
                    <span>{h.reason}</span>
                    <small>{fmtShortDate(new Date(h.created_at))}</small>
                    <b className={h.amount < 0 ? "neg" : "pos"}>
                      {h.amount > 0 ? "+" : ""}
                      {h.amount}
                    </b>
                  </li>
                ))}
              </ul>
            </div>
            <div className="panel">
              <h2 className="panel-title">Your rewards &amp; codes</h2>
              {items.length ? (
                <ul className="ledger">
                  {items.map((r) => (
                    <li key={r.id}>
                      <span>{itemById(r.item)?.name ?? r.item}</span>
                      <small>
                        {r.code}
                        {r.won ? " · WINNER" : r.fulfilled ? " · used" : ""}
                      </small>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="muted">
                  Nothing yet. <Link href="/rewards">Browse the reward store →</Link>
                </p>
              )}
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
