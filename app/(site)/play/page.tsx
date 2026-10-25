import type { Metadata } from "next";
import Link from "next/link";
import { ArcadeFrame } from "@/components/ArcadeFrame";
import { RTP_LEVELS, rtpLeaders, rtpMine } from "@/lib/arcade";
import { PinRun } from "@/components/PinRun";
import { currentAccount } from "@/lib/auth";
import { DAILY_GAME_COINS } from "@/lib/coins";
import { getDb } from "@/lib/db";
import { getWallet } from "@/lib/pinrun-db";
import { BOSS_ART, type Boss, LEVEL2_UNLOCK, LEVEL3_UNLOCK } from "@/lib/pinrun";
import { PinRunBoards } from "@/components/PinRunBoards";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Pin Run",
  description: "Pin Run and Race to the Pin: the 88 Risers arm wrestling games. Jump the tables, win the grip fights, pin the Kelvinator.",
};

export default async function PlayPage() {
  const me = await currentAccount();
  const db = await getDb();
  const [top, mine, rtpTop, rtpBest, wallet, top2, mine2, bosses, top3, mine3] = await Promise.all([
    db.query<{ display_name: string; handle: string; best: number }>(
      `SELECT a.display_name, a.handle, g.best FROM game_scores g JOIN accounts a ON a.id = g.account_id ORDER BY g.best DESC, g.updated_at ASC LIMIT 10`,
    ),
    me ? db.query<{ best: number }>(`SELECT best FROM game_scores WHERE account_id = $1`, [me.id]) : Promise.resolve([]),
    rtpLeaders(5),
    me ? rtpMine(me.id) : Promise.resolve({} as Awaited<ReturnType<typeof rtpMine>>),
    me ? getWallet(me.id) : Promise.resolve(null),
    db.query<{ display_name: string; handle: string; best: number }>(
      `SELECT a.display_name, a.handle, s.best FROM arcade_scores s JOIN accounts a ON a.id = s.account_id
       WHERE s.game = 'pinrun' AND s.level = '2' ORDER BY s.best DESC, s.updated_at ASC LIMIT 10`,
    ),
    me ? db.query<{ best: number }>(`SELECT best FROM arcade_scores WHERE account_id = $1 AND game = 'pinrun' AND level = '2'`, [me.id]) : Promise.resolve([]),
    db.query<Boss>(`SELECT id, name, coalesce(photo_url, card_url) AS photo FROM pullers WHERE NOT hidden ORDER BY id`),
    db.query<{ display_name: string; handle: string; best: number }>(
      `SELECT a.display_name, a.handle, s.best FROM arcade_scores s JOIN accounts a ON a.id = s.account_id
       WHERE s.game = 'pinrun' AND s.level = '3' ORDER BY s.best DESC, s.updated_at ASC LIMIT 10`,
    ),
    me ? db.query<{ best: number }>(`SELECT best FROM arcade_scores WHERE account_id = $1 AND game = 'pinrun' AND level = '3'`, [me.id]) : Promise.resolve([]),
  ]);
  const bossList = bosses.map((b) => ({ ...b, art: BOSS_ART.has(b.id) ? `/pinrun/bosses/${b.id}.webp` : null }));

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
            One button. Jump the tables, win the grip fights, don&apos;t fall in the chalk pit. Play any minigame here once a day and logged-in
            Risers earn +{DAILY_GAME_COINS} coins. Every coin you grab in Pin Run is banked for new lions in the Lion Temple. Score 12,000 to unlock Level 2: Crimson Peak, with moving ledges, power-ups, lion abilities and real Risers as bosses. Score 12,000 on Level 2 to reach Level 3: The Arena, with a hype meter, Beast Mode, double grips and supermatch finals. Prefer a straight-up arm wrestle?{" "}
            <a href="#race-to-the-pin">Play Race to the Pin</a>.
          </p>
        </div>
      </section>
      <section className="section" style={{ paddingTop: 16 }}>
        <div className="wrap play-grid">
          <PinRun loggedIn={!!me} best={mine[0]?.best ?? null} best2={mine2[0]?.best ?? null} best3={mine3[0]?.best ?? null} wallet={wallet} bosses={bossList} />
          <div className="panel">
            <PinRunBoards
              boards={[
                { label: "Lv.1 Lion Temple", rows: top, empty: "No scores yet. Claim the crown." },
                { label: "Lv.2 Crimson Peak", rows: top2, empty: `Locked until someone scores ${LEVEL2_UNLOCK.toLocaleString("en-AU")} on Level 1.` },
                { label: "Lv.3 The Arena", rows: top3, empty: `Locked until someone scores ${LEVEL3_UNLOCK.toLocaleString("en-AU")} on Level 2.` },
              ]}
            />
            {!me ? (
              <Link className="link-arrow" href="/account?next=/play">
                Log in to post a score <span>→</span>
              </Link>
            ) : null}
          </div>
        </div>
      </section>

      <section className="section" id="race-to-the-pin" style={{ paddingTop: 24 }}>
        <div className="wrap">
          <div className="section-head">
            <div>
              <p className="eyebrow">88 Risers Arcade</p>
              <h2 className="display">
                Race to <span className="gold-text">the Pin.</span>
              </h2>
            </div>
            <p className="lede">
              Time your pulls to drive their hand to the pad before they pin you. Four levels, from Rookie up to
              Kelvinator. Tap the button or press Space.
            </p>
          </div>
          <div className="arcade-wrap">
            <ArcadeFrame loggedIn={!!me} />
          </div>
          <div className="rtp-boards">
            {RTP_LEVELS.map((l) => (
              <div key={l.id} className={`panel rtp-board rtp-${l.id}`}>
                <h3 className="panel-title">{l.name}</h3>
                <ol className="coin-leaders">
                  {rtpTop[l.id].map((t, i) => (
                    <li key={i}>
                      <span className="cl-rank">{i === 0 ? "♛" : i + 1}</span>
                      <Link className="cl-name" href={`/members/${t.handle}`}>{t.display_name}</Link>
                      <b>{t.best.toLocaleString("en-AU")}</b>
                    </li>
                  ))}
                  {rtpTop[l.id].length === 0 ? <li className="muted">No wins yet.</li> : null}
                </ol>
                {me ? (
                  <p className="rtp-mine">
                    Your best: <b>{rtpBest[l.id] ? rtpBest[l.id]!.toLocaleString("en-AU") : "–"}</b>
                  </p>
                ) : null}
              </div>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
