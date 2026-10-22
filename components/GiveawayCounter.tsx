import Link from "next/link";
import type { Giveaway } from "@/lib/giveaway";
import { GIVEAWAY_PRIZE, GIVEAWAY_TITLE } from "@/lib/giveaway";
import { fmtDay, fmtTime } from "@/lib/schedule";
import { Countdown } from "./Countdown";

const plural = (n: number, one: string, many = `${one}s`) => `${n.toLocaleString("en-AU")} ${n === 1 ? one : many}`;

/** Full giveaway counter for /rewards: prize, live countdown, entries so far, your entries. */
export function GiveawayCounter({ g, loggedIn, cost }: { g: Giveaway; loggedIn: boolean; cost: number }) {
  const draw = new Date(g.drawAt);
  const done = draw.getTime() <= Date.now();
  return (
    <section className="giveaway" id="giveaway" aria-labelledby="giveaway-title">
      <div className="giveaway-main">
        <p className="eyebrow">{GIVEAWAY_TITLE}</p>
        <h2 id="giveaway-title" className="display">
          Win a <span className="gold-text">{GIVEAWAY_PRIZE.replace("88 Risers ", "")}.</span>
        </h2>
        <p className="giveaway-when">
          {done ? "Draw closed" : "Draw:"} {fmtDay(draw)} · {fmtTime(draw)} · announced on Instagram
        </p>
        {done ? (
          <p className="lede">{g.lastWinner ? `Winner: ${g.lastWinner}. Congratulations!` : "The draw is happening now. Good luck!"}</p>
        ) : (
          <Countdown to={g.drawAt} label="Time until the giveaway draw" />
        )}
      </div>
      <div className="giveaway-stats">
        <div>
          <b>{g.entries.toLocaleString("en-AU")}</b>
          <span>{g.entries === 1 ? "entry" : "entries"}</span>
        </div>
        <div>
          <b>{g.entrants.toLocaleString("en-AU")}</b>
          <span>{g.entrants === 1 ? "Riser in" : "Risers in"}</span>
        </div>
        <div>
          <b>{loggedIn ? g.mine : "–"}</b>
          <span>yours</span>
        </div>
        {!done ? (
          loggedIn ? (
            <a className="btn btn-primary btn-sm" href="#entry-tee">
              Enter for {cost} coins
            </a>
          ) : (
            <Link className="btn btn-primary btn-sm" href="/account?next=/rewards%23giveaway">
              Get free coins to enter
            </Link>
          )
        ) : null}
        {loggedIn && g.mine && g.entries ? (
          <p className="giveaway-chance">Your odds right now: {Math.round((g.mine / g.entries) * 100)}%</p>
        ) : null}
      </div>
    </section>
  );
}

/** Compact homepage banner. Days are worked out at render time (the page re-renders every minute). */
export function GiveawayStrip({ g }: { g: Giveaway }) {
  const ms = new Date(g.drawAt).getTime() - Date.now();
  if (ms <= 0) return null;
  const days = Math.floor(ms / 86400000);
  return (
    <Link href="/rewards#giveaway" className="sm-strip gw-strip">
      <span className="sm-strip-tag">{GIVEAWAY_TITLE}</span>
      <b>{days >= 1 ? plural(days, "day") : "Today"}</b>
      <span>
        to win a Club Tee · {plural(g.entries, "entry", "entries")} so far
      </span>
      <span className="sm-strip-go">Enter →</span>
    </Link>
  );
}
