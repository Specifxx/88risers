import type { Metadata } from "next";
import Link from "next/link";
import { PinRun } from "@/components/PinRun";
import { currentAccount } from "@/lib/auth";
import { DAILY_GAME_COINS } from "@/lib/coins";
import { getDb } from "@/lib/db";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Pin Run",
  description: "Pin Run: the 88 Risers arm wrestling platformer. Jump the tables, win the grip fights, chase the high score.",
};

export default async function PlayPage() {
  const me = await currentAccount();
  const db = await getDb();
  const [top, mine] = await Promise.all([
    db.query<{ display_name: string; best: number }>(
      `SELECT a.display_name, g.best FROM game_scores g JOIN accounts a ON a.id = g.account_id ORDER BY g.best DESC, g.updated_at ASC LIMIT 10`,
    ),
    me ? db.query<{ best: number }>(`SELECT best FROM game_scores WHERE account_id = $1`, [me.id]) : Promise.resolve([]),
  ]);

  return (
    <>
      <section className="page-hero" style={{ paddingBottom: 24 }}>
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / Play
          </p>
          <h1 className="display">
            Pin <span className="gold-text">Run.</span>
          </h1>
          <p className="lede">
            One button. Jump the tables, win the grip fights, don&apos;t fall in the chalk pit. Logged-in Risers earn{" "}
            {DAILY_GAME_COINS} coins for their first run each day.
          </p>
        </div>
      </section>
      <section className="section" style={{ paddingTop: 16 }}>
        <div className="wrap play-grid">
          <PinRun loggedIn={!!me} best={mine[0]?.best ?? null} />
          <div className="panel">
            <h2 className="panel-title">High scores</h2>
            <ol className="coin-leaders">
              {top.map((t, i) => (
                <li key={i}>
                  <span className="cl-rank">{i === 0 ? "♛" : i + 1}</span>
                  <span className="cl-name">{t.display_name}</span>
                  <b>{t.best.toLocaleString("en-AU")}</b>
                </li>
              ))}
              {top.length === 0 ? <li className="muted">No scores yet. Claim the crown.</li> : null}
            </ol>
            {!me ? (
              <Link className="link-arrow" href="/account?next=/play">
                Log in to post a score <span>→</span>
              </Link>
            ) : null}
          </div>
        </div>
      </section>
    </>
  );
}
