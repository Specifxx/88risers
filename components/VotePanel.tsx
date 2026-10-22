"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { startTransition, useActionState, useEffect, useState } from "react";
import { type FormState, castPick } from "@/app/(site)/account/actions";
import { lionSays } from "@/lib/lion";
import { type Pools, fmtOdds, oddsOf, payoutAt, quoteOdds } from "@/lib/odds";

interface Side {
  id: number;
  name: string;
}

/** Pick a winner, optionally stake coins at the live pool odds. Picks are final once locked. */
export function VotePanel({
  matchId,
  a,
  b,
  loggedIn,
  balance,
  maxStake,
  reward,
  pools,
  arm,
}: {
  matchId: number;
  a: Side;
  b: Side;
  loggedIn: boolean;
  balance: number;
  maxStake: number;
  reward: number;
  pools: Pools;
  arm: string;
}) {
  const [pick, setPick] = useState<number | null>(null);
  const [stake, setStake] = useState(0);
  const [state, action, pending] = useActionState<FormState, FormData>(castPick, { status: "idle" });
  const cap = Math.min(balance, maxStake);
  const router = useRouter();
  const odds = oddsOf(pools);
  const side = pick === a.id ? "a" : pick === b.id ? "b" : null;
  const quote = side && stake > 0 ? quoteOdds(stake, side, pools) : 0;
  const est = payoutAt(stake, quote);

  useEffect(() => {
    if (state.status !== "ok") return;
    lionSays("roar", stake ? `${stake} coins on the line? Bold. ROAR!` : "Pick locked. ROAR!");
    // Show the confirmation, then reload the page to reveal the crowd split.
    const t = setTimeout(() => router.refresh(), 1800);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state]);

  if (!loggedIn) {
    return (
      <div className="vote-box">
        <p className="vote-lede">
          Pick the winner and earn <b>{reward} coins</b> if you&apos;re right. Stake coins at live odds: the less-backed puller pays more.
        </p>
        <div className="btn-row">
          <Link className="btn btn-primary" href="/account?next=/supermatch">
            Create a free account to vote
          </Link>
          <Link className="btn btn-ghost" href="/account?mode=login&next=/supermatch">
            Log in
          </Link>
        </div>
      </div>
    );
  }

  return (
    <form
      className="vote-box"
      onSubmit={(e) => {
        e.preventDefault();
        if (!pick) return;
        const fd = new FormData(e.currentTarget);
        startTransition(() => action(fd));
      }}
    >
      <input type="hidden" name="match_id" value={matchId} />
      <input type="hidden" name="pick_id" value={pick ?? ""} />
      <p className="vote-lede">
        Who takes it on the {arm.toLowerCase()}? A correct pick earns <b>{reward} coins</b>. Your pick is final once locked.
      </p>
      <div className="vote-picks">
        {[a, b].map((s) => (
          <button type="button" key={s.id} className="vote-pick" aria-pressed={pick === s.id} onClick={() => setPick(s.id)}>
            {s.name}
            <small>pays {fmtOdds(s.id === a.id ? odds.a : odds.b)}</small>
          </button>
        ))}
      </div>
      <div className="vote-stake">
        <label htmlFor="stake">
          Stake coins <em>optional · odds lock in when you bet</em>
        </label>
        <div className="stake-row">
          <input
            id="stake"
            name="stake"
            type="range"
            min={0}
            max={cap}
            step={cap >= 50 ? 5 : 1}
            value={stake}
            onChange={(e) => setStake(Number(e.target.value))}
            disabled={cap === 0}
          />
          <b>
            {stake} <small>/ {balance}</small>
          </b>
        </div>
      </div>
      {stake > 0 ? (
        <p className="vote-est" aria-live="polite">
          {side ? (
            <>
              Lock in <b>{fmtOdds(quote)}</b>: if {(side === "a" ? a : b).name.split(" ")[0]} wins you get back{" "}
              <b>{est.toLocaleString("en-AU")}</b> coins, plus the {reward}-coin bonus.
            </>
          ) : (
            "Choose a puller to see your return."
          )}
        </p>
      ) : null}
      {state.status === "error" ? <div className="form-error">{state.message}</div> : null}
      {state.status === "ok" ? <div className="form-ok">{state.message}</div> : null}
      <button className="btn btn-primary submit" disabled={!pick || pending || state.status === "ok"}>
        {pending ? "Locking in…" : pick ? `Lock in ${pick === a.id ? a.name.split(" ")[0] : b.name.split(" ")[0]}` : "Choose a puller"}
      </button>
    </form>
  );
}
