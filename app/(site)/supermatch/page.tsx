import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { Countdown } from "@/components/Countdown";
import { LiveRefresh } from "@/components/LiveRefresh";
import { VotePanel } from "@/components/VotePanel";
import { currentAccount } from "@/lib/auth";
import { MAX_STAKE, coinLeaders } from "@/lib/coins";
import { type Puller, getPuller } from "@/lib/data";
import { tierFor } from "@/lib/elo";
import { POOL_SEED, fmtOdds, oddsOf, payoutAt } from "@/lib/odds";
import { fmtDay, fmtTime } from "@/lib/schedule";
import { formatId } from "@/lib/site";
import { armLabel, featuredSupermatch, isOpen, myPick, predictionRecord, recordLabel, topPredictors } from "@/lib/supermatch";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Supermatch",
  description: "Pick the winner of the 88 Risers supermatch and earn 88Risers coins.",
};

function Fighter({ p, side, winner, odds, live }: { p: Puller; side: "a" | "b"; winner: number | null; odds: number; live: boolean }) {
  const cls = winner ? (winner === p.id ? " is-winner" : " is-loser") : "";
  return (
    <div className={`sm-fighter sm-${side}${cls}`}>
      <div className="sm-card">
        {p.card_url ? <Image src={p.card_url} alt={`${p.name}'s champion card`} fill sizes="(max-width: 720px) 45vw, 340px" priority /> : null}
      </div>
      <p className="sm-id">{formatId(p.id)}</p>
      <h2 className="sm-name">{p.name}</h2>
      {p.title ? <p className="sm-title">{p.title}</p> : null}
      <p className="sm-odds" title="Coins returned per coin staked, stake included">
        {live ? "Pays" : "Paid"} <b>{fmtOdds(odds)}</b>
      </p>
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
  const [m, me, leaders, predictors] = await Promise.all([featuredSupermatch(), currentAccount(), coinLeaders(10), topPredictors(5)]);
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
  const [a, b, mine, rec] = await Promise.all([
    getPuller(m.a_id, true),
    getPuller(m.b_id, true),
    me ? myPick(m.id, me.id) : null,
    me ? predictionRecord(me.id) : null,
  ]);
  if (!a || !b) return null;
  const open = isOpen(m);
  const total = m.a_votes + m.b_votes;
  const pctA = total ? Math.round((m.a_votes / total) * 100) : 50;
  const pools = { a: m.a_pot, b: m.b_pot };
  const odds = oddsOf(pools);
  const mySide = mine ? (mine.pick_id === m.a_id ? "a" : "b") : null;
  // Bets from before odds were locked fall back to the current price (as at settlement).
  const myOdds = mine && mySide ? (mine.odds ?? odds[mySide]) : 0;
  const myPayout = mine ? payoutAt(mine.stake, myOdds) : 0;
  const closes = new Date(m.closes_at);
  const won = m.winner_id && mine ? mine.pick_id === m.winner_id : null;

  return (
    <>
      <section className="page-hero sm-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / Supermatch
          </p>
          <p className="eyebrow">
            {m.title} · {armLabel(m)}
          </p>
          <h1 className="display">
            {a.name.split(" ")[0]} <span className="gold-text">vs</span> {b.name.split(" ")[0]}.
          </h1>
          {m.blurb ? <p className="lede">{m.blurb}</p> : null}
        </div>
      </section>

      <section className="section" style={{ paddingTop: 40 }}>
        <div className="wrap">
          <div className="sm-arena">
            <Fighter p={a} side="a" winner={m.winner_id} odds={odds.a} live={!m.winner_id} />
            <div className="sm-vs-wrap">
              <div className="sm-vs" aria-hidden>
                VS
              </div>
              <span className={`sm-arm sm-arm-${m.arm}`}>{armLabel(m)}</span>
            </div>
            <Fighter p={b} side="b" winner={m.winner_id} odds={odds.b} live={!m.winner_id} />
          </div>

          {open ? <LiveRefresh seconds={20} /> : null}
          <div className="sm-split" aria-label={`Crowd: ${pctA}% ${a.name}, ${100 - pctA}% ${b.name}`}>
              <div className="sm-split-bar">
                <span style={{ width: `${pctA}%` }} />
              </div>
              <div className="sm-split-labels">
                <span>
                  {pctA}% · {m.a_votes} {m.a_votes === 1 ? "pick" : "picks"} · {m.a_pot} coins
                </span>
                <span>{m.pot ? `${m.pot} coins in the pool` : "No stakes yet"}</span>
                <span>
                  {m.b_pot} coins · {m.b_votes} {m.b_votes === 1 ? "pick" : "picks"} · {100 - pctA}%
                </span>
              </div>
          </div>

          <div className="sm-panel">
            {m.winner_id ? (
              <div className="vote-box sm-result">
                <p className="eyebrow">Result</p>
                <h3>{(m.winner_id === a.id ? a : b).name} wins.</h3>
                {mine ? (
                  <p className="vote-lede">
                    {won
                      ? `You called it! +${m.reward} coins${mine.stake ? `, plus ${myPayout} from your ${mine.stake}-coin stake at ${fmtOdds(myOdds)}` : ""}.`
                      : mine.stake ? "Not this time. Your stake went to the lion." : "Not this time."}
                  </p>
                ) : null}
              </div>
            ) : mine ? (
              <div className="vote-box">
                <p className="eyebrow">Your pick</p>
                <h3>{mine.pick_id === a.id ? a.name : b.name}</h3>
                <p className="vote-lede">
                  {mine.stake
                    ? `${mine.stake} coins at ${fmtOdds(myOdds)}, locked in. Pays ${myPayout} coins if ${(mySide === "a" ? a : b).name.split(" ")[0]} wins. `
                    : ""}
                  {mine.stake ? "" : "Locked in. "}Coins land in your account when the result is in.
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
                pools={pools}
                arm={armLabel(m)}
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
                <h2 className="panel-title">Top predictors</h2>
                {rec ? (
                  <p className="my-record">
                    Your record: <b>{recordLabel(rec) ?? "no results yet"}</b>
                    {rec.streak > 1 ? <span> · {rec.streak} in a row 🔥</span> : null}
                  </p>
                ) : null}
                <ol className="coin-leaders">
                  {predictors.map((p, i) => (
                    <li key={p.handle}>
                      <span className="cl-rank">{i === 0 ? "♛" : i + 1}</span>
                      <span className="cl-name">
                        {p.display_name}
                        {p.badge ? <i className="cl-lion" aria-label="Lion badge" /> : null}
                      </span>
                      <b>{recordLabel(p)}</b>
                    </li>
                  ))}
                  {predictors.length === 0 ? <li className="muted">The first results land after this supermatch.</li> : null}
                </ol>
              </div>
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
            How the odds work: prices move with the coins staked on each side, so the less-backed puller pays more.
            The lion puts {POOL_SEED} coins on each side to start (2.00× each). Your bet locks in the odds at the
            moment you place it; later bets change the price for the next person, not for you.
          </p>
          <p className="fine" style={{ marginTop: 10 }}>
            Free to play. 88Risers coins are play money for predictions and club rewards; they can&apos;t be bought,
            sold or exchanged for cash.
          </p>
        </div>
      </section>
    </>
  );
}
