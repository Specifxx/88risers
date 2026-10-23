import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { AchievementWall } from "@/components/AchievementWall";
import { ChalkLift } from "@/components/ChalkLift";
import { RiserPass } from "@/components/RiserPass";
import { chalkOf, chalkSettings, liftCompletedEver } from "@/lib/chalk";
import { ACHIEVEMENTS, earnedAchievements } from "@/lib/achievements";
import { RTP_LEVELS } from "@/lib/arcade";
import { currentAccount } from "@/lib/auth";
import { type MemberProfile, getMember } from "@/lib/members";
import { fmtShortDate } from "@/lib/schedule";
import { formatId } from "@/lib/site";
import { type PredictionRecord, predictionRecord, recordLabel } from "@/lib/supermatch";

export const dynamic = "force-dynamic";

const cleanHandle = (raw: string) => decodeURIComponent(raw).replace(/^@/, "").toLowerCase();

export async function generateMetadata({ params }: PageProps<"/members/[handle]">): Promise<Metadata> {
  const m = await getMember(cleanHandle((await params).handle));
  if (!m) return { title: "Member not found" };
  return {
    title: `${m.display_name} (@${m.handle})`,
    description: `${m.display_name}'s 88 Risers member pass: achievements, supermatch record and game scores.`,
    robots: { index: false },
  };
}

const earnedFor = (m: MemberProfile, rec: PredictionRecord, liftDone: boolean) =>
  earnedAchievements({
    memberNo: m.member_no,
    coins: m.coins,
    rec,
    pinRun: m.pinRun,
    rtp: m.rtp,
    items: m.items,
    wonGiveaway: m.won_giveaway,
    liftDone,
  });

const n = (v: number | null | undefined) => (v ? v.toLocaleString("en-AU") : "–");

export default async function MemberPage({ params }: PageProps<"/members/[handle]">) {
  const m = await getMember(cleanHandle((await params).handle));
  if (!m) notFound();
  const me = await currentAccount();
  const isMe = me?.handle === m.handle;
  const [rec, mine, myRec] = await Promise.all([
    predictionRecord(m.id),
    me && !isMe ? getMember(me.handle) : null,
    me && !isMe ? predictionRecord(me.id) : null,
  ]);
  const settings = await chalkSettings();
  const [chalk, liftDone, myChalk, myLift] = await Promise.all([
    chalkOf(m.id),
    liftCompletedEver(m.id, settings.target),
    mine ? chalkOf(mine.id) : 0,
    mine ? liftCompletedEver(mine.id, settings.target) : false,
  ]);
  const earned = earnedFor(m, rec, liftDone);
  const first = m.display_name.split(" ")[0];

  // Head-to-head rows: [label, mine, theirs, link to go beat it]
  const rows: [string, number, number, string | null][] =
    mine && myRec
      ? [
          ["Supermatch calls", myRec.correct, rec.correct, "/supermatch"],
          ["Best streak", myRec.bestStreak, rec.bestStreak, "/supermatch"],
          ["Coins", mine.coins, m.coins, "/play"],
          ["Chalk this season", myChalk, chalk, "/chalk"],
          ["Achievements", earnedFor(mine, myRec, myLift).size, earned.size, null],
          ["Pin Run", mine.pinRun ?? 0, m.pinRun ?? 0, "/play"],
          ...RTP_LEVELS.map(
            (l) => [`Race to the Pin · ${l.name}`, mine.rtp[l.id] ?? 0, m.rtp[l.id] ?? 0, "/play#race-to-the-pin"] as [string, number, number, string],
          ),
        ]
      : [];
  const wins = rows.filter(([, a, b]) => a > b).length;
  const losses = rows.filter(([, a, b]) => b > a).length;

  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / <Link href="/pullers">Riser Database</Link> / @{m.handle}
          </p>
          <p className="eyebrow">
            Member #{m.member_no}
            {m.riser_id ? (
              <>
                {" · "}
                <Link href={`/pullers/${m.riser_id}`} className="gold">
                  Riser {formatId(m.riser_id)}
                </Link>
              </>
            ) : null}
          </p>
          <h1 className="display">
            {first}
            <span className="gold-text">.</span>
          </h1>
          <p className="lede">
            @{m.handle} · member since {fmtShortDate(new Date(m.created_at))} · {earned.size} of {ACHIEVEMENTS.length}{" "}
            achievements
          </p>
          {isMe || m.riser_id ? (
            <div className="btn-row" style={{ marginTop: 20 }}>
              {m.riser_id ? (
                <Link className="btn btn-sm btn-primary" href={`/pullers/${m.riser_id}`}>
                  Riser profile {formatId(m.riser_id)} · record &amp; matches →
                </Link>
              ) : null}
              {isMe ? (
                <Link className="btn btn-sm" href="/account">
                  Back to your account
                </Link>
              ) : null}
            </div>
          ) : null}
        </div>
      </section>

      <section className="section" style={{ paddingTop: 40 }}>
        <div className="wrap account-grid">
          <div>
            <RiserPass
              name={m.display_name}
              handle={m.handle}
              coins={m.coins}
              style={{ frame: m.frame, title: m.title, badge: m.badge }}
              record={recordLabel(rec)}
            />
            <div className="panel" style={{ marginTop: 20 }}>
              <h2 className="panel-title">
                {first}&apos;s Lift
                <small>
                  <Link href="/chalk">Chalkboard →</Link>
                </small>
              </h2>
              <ChalkLift chalk={chalk} target={settings.target} compact />
            </div>
          </div>
          <div className="account-cols">
            <AchievementWall earned={earned} />

            {rows.length ? (
              <div className="panel h2h">
                <h2 className="panel-title">
                  You vs {first}
                  <small>
                    {wins}–{losses}
                  </small>
                </h2>
                <table className="h2h-table">
                  <thead>
                    <tr>
                      <th />
                      <th className="num">You</th>
                      <th className="num">{first}</th>
                      <th />
                    </tr>
                  </thead>
                  <tbody>
                    {rows.map(([label, a, b, href]) => (
                      <tr key={label}>
                        <td>{label}</td>
                        <td className={`num${a > b ? " lead" : ""}`}>{n(a)}</td>
                        <td className={`num${b > a ? " lead" : ""}`}>{n(b)}</td>
                        <td className="num">
                          {href && b > a ? (
                            <Link className="h2h-go" href={href}>
                              Beat it →
                            </Link>
                          ) : null}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : !me ? (
              <div className="panel">
                <p className="muted" style={{ margin: 0 }}>
                  <Link href={`/account?next=/members/${m.handle}`}>Log in</Link> to see how you stack up against {first}.
                </p>
              </div>
            ) : null}

            <div className="panel">
              <h2 className="panel-title">Record &amp; scores</h2>
              <div className="pick-stats">
                <div>
                  <b>{rec.settled ? `${rec.correct}/${rec.settled}` : "–"}</b>
                  <span>supermatch calls</span>
                </div>
                <div>
                  <b>{rec.rate === null ? "–" : `${rec.rate}%`}</b>
                  <span>hit rate</span>
                </div>
                <div>
                  <b>{rec.streak}</b>
                  <span>streak</span>
                </div>
                <div>
                  <b>{rec.bestStreak}</b>
                  <span>best streak</span>
                </div>
              </div>
              <ul className="ledger">
                <li>
                  <span>Pin Run</span>
                  <b>{n(m.pinRun)}</b>
                </li>
                {RTP_LEVELS.map((l) => (
                  <li key={l.id}>
                    <span>Race to the Pin · {l.name}</span>
                    <b>{n(m.rtp[l.id])}</b>
                  </li>
                ))}
              </ul>
              <p className="fine" style={{ marginTop: 12 }}>
                Who members back stays private; only the overall record is shown.
              </p>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
