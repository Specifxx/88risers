import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { Countdown } from "@/components/Countdown";
import { VotePanel } from "@/components/VotePanel";
import { currentAccount } from "@/lib/auth";
import { MAX_STAKE, coinLeaders } from "@/lib/coins";
import { type Puller, getPuller } from "@/lib/data";
import { tierFor } from "@/lib/elo";
import { fmtDay, fmtTime } from "@/lib/schedule";
import { formatId } from "@/lib/site";
import { featuredSupermatch, isOpen, myPick } from "@/lib/supermatch";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Supermatch",
  description: "Pick the winner of the 88 Risers supermatch and earn 88Risers coins.",
};

function Fighter({ p, side, winner }: { p: Puller; side: "a" | "b"; winner: number | null }) {
  const cls = winner ? (winner === p.id ? " is-winner" : " is-loser") : "";
  return (
    <div className={`sm-fighter sm-${side}${cls}`}>
      <div className="sm-card">
        {p.card_url ? <Image src={p.card_url} alt={`${p.name}'s champion card`} fill sizes="(max-width: 720px) 45vw, 340px" priority /> : null}
      </div>
      <p className="sm-id">{formatId(p.id)}</p>
      <h2 className="sm-name">{p.name}</h2>
      {p.title ? <p className="sm-title">{p.title}</p> : null}
      <p className="sm-stats">
        <span>{p.elo} Elo</span>
        <span>{tierFor(p.elo).name}</span>
        <span>
          {p.wins}–{p.losses}
        </span>
      </p>
    </div>
  );
}

export default async function SupermatchPage() {
  const [m, me, leaders] = await Promise.all([featuredSupermatch(), currentAccount(), coinLeaders(10)]);
  if (!m) {
    return (
      <section className="page-hero">
        <div className="wrap">
          <h1 className="display">
            No supermatch <span className="gold-text">yet.</span>
          </h1>
          <p className="lede">The next one will be announced on Instagram.</p>
        </div>
      </section>
    );
  }
  const [a, b, mine] = await Promise.all([getPuller(m.a_id, true), getPuller(m.b_id, true), me ? myPick(m.id, me.id) : null]);
  if (!a || !b) return null;
  const open = isOpen(m);
  const total = m.a_votes + m.b_votes;
  const pctA = total ? Math.round((m.a_votes / total) * 100) : 50;
  const showSplit = !open || !!mine;
  const closes = new Date(m.closes_at);
  const won = m.winner_id && mine ? mine.pick_id === m.winner_id : null;

  return (
    <>
      <section className="page-hero sm-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / Supermatch
          </p>
          <p className="eyebrow">{m.title}</p>
          <h1 className="display">
            {a.name.split(" ")[0]} <span className="gold-text">vs</span> {b.name.split(" ")[0]}.
          </h1>
          {m.blurb ? <p className="lede">{m.blurb}</p> : null}
        </div>
      </section>

      <section className="section" style={{ paddingTop: 40 }}>
        <div className="wrap">
          <div className="sm-arena">
            <Fighter p={a} side="a" winner={m.winner_id} />
            <div className="sm-vs" aria-hidden>
              VS
            </div>
            <Fighter p={b} side="b" winner={m.winner_id} />
          </div>

          {showSplit ? (
            <div className="sm-split" aria-label={`Crowd: ${pctA}% ${a.name}, ${100 - pctA}% ${b.name}`}>
              <div className="sm-split-bar">
                <span style={{ width: `${pctA}%` }} />
              </div>
              <div className="sm-split-labels">
                <span>
                  {pctA}% · {m.a_votes} {m.a_votes === 1 ? "pick" : "picks"}
                </span>
                <span>{m.pot ? `${m.pot} coins staked` : "The crowd's pick"}</span>
                <span>
                  {m.b_votes} {m.b_votes === 1 ? "pick" : "picks"} · {100 - pctA}%
                </span>
              </div>
            </div>
          ) : null}

          <div className="sm-panel">
            {m.winner_id ? (
              <div className="vote-box sm-result">
                <p className="eyebrow">Result</p>
                <h3>{(m.winner_id === a.id ? a : b).name} wins.</h3>
                {mine ? (
                  <p className="vote-lede">
                    {won
                      ? `You called it! +${m.reward} coins${mine.stake ? `, plus ${mine.stake * 2} back from your stake` : ""}.`
                      : "Not this time. Your stake went to the lion."}
                  </p>
                ) : null}
              </div>
            ) : mine ? (
              <div className="vote-box">
                <p className="eyebrow">Your pick</p>
                <h3>{mine.pick_id === a.id ? a.name : b.name}</h3>
                <p className="vote-lede">
                  {mine.stake ? `${mine.stake} coins staked. ` : ""}Locked in. Coins land in your account when the result is in.
                </p>
              </div>
            ) : open ? (
              <VotePanel
                matchId={m.id}
                a={{ id: a.id, name: a.name }}
                b={{ id: b.id, name: b.name }}
                loggedIn={!!me}
                balance={me?.coins ?? 0}
                maxStake={MAX_STAKE}
                reward={m.reward}
              />
            ) : (
              <div className="vote-box">
                <h3>Voting closed.</h3>
                <p className="vote-lede">Result coming soon.</p>
              </div>
            )}

            <div className="sm-side">
              {open ? (
                <div className="sm-clock">
                  <p className="eyebrow">Voting closes</p>
                  <p className="sm-when">
                    {fmtDay(closes)} · {fmtTime(closes)}
                  </p>
                  <Countdown to={m.closes_at} />
                </div>
              ) : null}
              <div className="panel">
                <h2 className="panel-title">Coin leaders</h2>
                <ol className="coin-leaders">
                  {leaders.map((l, i) => (
                    <li key={l.handle}>
                      <span className="cl-rank">{i === 0 ? "♛" : i + 1}</span>
                      <span className="cl-name">
                        {l.display_name}
                        {l.badge ? <i className="cl-lion" aria-label="Lion badge" /> : null}
                      </span>
                      <b>{l.coins}</b>
                    </li>
                  ))}
                  {leaders.length === 0 ? <li className="muted">Be the first on the board.</li> : null}
                </ol>
                <Link className="link-arrow" href="/rewards">
                  Spend coins <span>→</span>
                </Link>
              </div>
            </div>
          </div>
          <p className="fine" style={{ marginTop: 28 }}>
            Free to play. 88Risers coins are play money for predictions and club rewards; they can&apos;t be bought,
            sold or exchanged for cash.
          </p>
        </div>
      </section>
    </>
  );
}
