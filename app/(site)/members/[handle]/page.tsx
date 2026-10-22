import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { RiserPass } from "@/components/RiserPass";
import { currentAccount } from "@/lib/auth";
import { RTP_LEVELS } from "@/lib/arcade";
import { getMember } from "@/lib/members";
import { fmtShortDate } from "@/lib/schedule";
import { predictionRecord, recordLabel } from "@/lib/supermatch";

export const dynamic = "force-dynamic";

const cleanHandle = (raw: string) => decodeURIComponent(raw).replace(/^@/, "").toLowerCase();

export async function generateMetadata({ params }: PageProps<"/members/[handle]">): Promise<Metadata> {
  const m = await getMember(cleanHandle((await params).handle));
  if (!m) return { title: "Member not found" };
  return {
    title: `${m.display_name} (@${m.handle})`,
    description: `${m.display_name}'s 88 Risers member pass: coins, supermatch picks and game scores.`,
    robots: { index: false },
  };
}

export default async function MemberPage({ params }: PageProps<"/members/[handle]">) {
  const m = await getMember(cleanHandle((await params).handle));
  if (!m) notFound();
  const [rec, me] = await Promise.all([predictionRecord(m.id), currentAccount()]);
  const settled = rec.history.filter((h) => h.settled_at);
  const isMe = me?.handle === m.handle;

  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / <Link href="/pullers">Riser Database</Link> / @{m.handle}
          </p>
          <h1 className="display">
            {m.display_name.split(" ")[0]}
            <span className="gold-text">.</span>
          </h1>
          <p className="lede">
            @{m.handle} · member since {fmtShortDate(new Date(m.created_at))}. Riser IDs are earned by pulling at a
            meet; <Link href="/join">register</Link> to get yours.
          </p>
          {isMe ? (
            <div className="btn-row" style={{ marginTop: 20 }}>
              <Link className="btn btn-sm" href="/account">
                Back to your account
              </Link>
            </div>
          ) : null}
        </div>
      </section>

      <section className="section" style={{ paddingTop: 40 }}>
        <div className="wrap account-grid">
          <RiserPass
            name={m.display_name}
            handle={m.handle}
            coins={m.coins}
            style={{ frame: m.frame, title: m.title, badge: m.badge }}
            record={recordLabel(rec)}
          />
          <div className="account-cols">
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
                  <b>{rec.picks - rec.settled}</b>
                  <span>pending</span>
                </div>
              </div>
              {settled.length ? (
                <ul className="ledger">
                  {settled.map((h) => {
                    const won = h.pick_id === h.winner_id;
                    return (
                      <li key={h.match_id}>
                        <span>
                          {h.title} · {h.arm === "left" ? "left arm" : "right arm"}
                          <br />
                          <small>Picked {h.pick_name}</small>
                        </span>
                        <small className={won ? "pick-won" : "pick-lost"}>{won ? "Called it" : "Missed"}</small>
                      </li>
                    );
                  })}
                </ul>
              ) : (
                <p className="muted">No settled picks yet.</p>
              )}
            </div>
            <div className="panel">
              <h2 className="panel-title">Arcade bests</h2>
              <ul className="ledger">
                <li>
                  <span>Pin Run</span>
                  <b>{m.pinRun ? m.pinRun.toLocaleString("en-AU") : "–"}</b>
                </li>
                {RTP_LEVELS.map((l) => (
                  <li key={l.id}>
                    <span>Race to the Pin · {l.name}</span>
                    <b>{m.rtp[l.id] ? m.rtp[l.id]!.toLocaleString("en-AU") : "–"}</b>
                  </li>
                ))}
              </ul>
              <Link className="link-arrow" href="/play">
                Beat these scores <span>→</span>
              </Link>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
