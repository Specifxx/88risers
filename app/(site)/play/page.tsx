import type { Metadata } from "next";
import Link from "next/link";
import { ArcadeFrame } from "@/components/ArcadeFrame";
import { RTP_LEVELS, rtpLeaders, rtpMine } from "@/lib/arcade";
import { PinRun } from "@/components/PinRun";
import { currentAccount } from "@/lib/auth";
import { DAILY_GAME_COINS } from "@/lib/coins";
import { getDb } from "@/lib/db";
import { getWallet } from "@/lib/pinrun-db";
import { BOSS_ART, type Boss, LEVEL2_UNLOCK, LEVEL3_UNLOCK, RAID_REWARD, RAID_TOP_BONUS } from "@/lib/pinrun";
import { getRaid, raidBoard } from "@/lib/raid";
import { KatanaDraw } from "@/components/KatanaDraw";
import { KATANA_ENTRY } from "@/lib/katana";
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
  const raid = await getRaid();
  const katanaTop = await db.query<{ display_name: string; handle: string; best: number; clears: number }>(
    `SELECT a.display_name, a.handle, max(k.wins)::int AS best, count(*) FILTER (WHERE k.wins >= 6)::int AS clears
     FROM katana_runs k JOIN accounts a ON a.id = k.account_id
     WHERE k.ended_at IS NOT NULL AND k.wins > 0
     GROUP BY a.id, a.display_name, a.handle ORDER BY best DESC, clears DESC, min(k.started_at) ASC LIMIT 10`,
  );
  const raidTop = await raidBoard(raid.id);
  // Bosses need a face: cartoon art or a photo (Risers without either sit out until they have one).
  const bossList = bosses.map((b) => ({ ...b, art: BOSS_ART.has(b.id) ? `/pinrun/bosses/${b.id}.webp` : null })).filter((b) => b.art || b.photo);

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
            Risers earn +{DAILY_GAME_COINS} coins. Every coin you grab in Pin Run is banked for new lions in the Lion Temple. Score 5,000 to unlock Level 2: Crimson Peak, with moving ledges, power-ups, lion abilities and real Risers as bosses. Score 5,000 on Level 2 to reach Level 3: The Arena, where a random Riser chases you and every run chips at the club&apos;s shared Riser Boss. Prefer a straight-up arm wrestle?{" "}
            <a href="#race-to-the-pin">Play Race to the Pin</a>.
          </p>
        </div>
      </section>
      <section className="section" style={{ paddingTop: 16 }}>
        <div className="wrap play-grid">
          <PinRun loggedIn={!!me} best={mine[0]?.best ?? null} best2={mine2[0]?.best ?? null} best3={mine3[0]?.best ?? null} raid={raid} wallet={wallet} bosses={bossList} />
          <div className="panel">
            <PinRunBoards
              boards={[
                { label: "Lv.1 Lion Temple", rows: top, empty: "No scores yet. Claim the crown." },
                { label: "Lv.2 Crimson Peak", rows: top2, empty: `Locked until someone scores ${LEVEL2_UNLOCK.toLocaleString("en-AU")} on Level 1.` },
                { label: "Lv.3 The Arena", rows: top3, empty: `Locked until someone scores ${LEVEL3_UNLOCK.toLocaleString("en-AU")} on Level 2.` },
                {
                  label: "Club Raid",
                  rows: raidTop,
                  empty: "No hits yet. Every Level 3 run chips at the Riser Boss.",
                  note: `Riser Boss: ${raid.hp.toLocaleString("en-AU")} / ${raid.hpMax.toLocaleString("en-AU")} HP left. Every Level 3 run hits it, whichever Riser is chasing you. When the club takes it down, everyone who landed a hit gets ${RAID_REWARD} Temple coins (top damage +${RAID_TOP_BONUS}).`,
                  unit: "dmg",
                },
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

      <section className="section" id="katana-draw" style={{ paddingTop: 24 }}>
        <div className="wrap">
          <div className="section-head">
            <div>
              <p className="eyebrow">88 Risers Arcade</p>
              <h2 className="display">
                Katana <span className="gold-text">Draw.</span>
              </h2>
            </div>
            <p className="lede">
              A quick-draw ladder for the 88 Risers katana. Spend {KATANA_ENTRY} Temple coins to step up, then out-draw six Risers in a row. Cash out
              after any win, or risk the pot for more.
            </p>
          </div>
          <div className="play-grid">
            <KatanaDraw loggedIn={!!me} coins={wallet?.coins ?? null} bosses={bossList} skin={wallet?.skin} />
            <div className="panel">
              <h2 className="panel-title">Katana Masters</h2>
              <ol className="coin-leaders">
                {katanaTop.map((t, i) => (
                  <li key={t.handle}>
                    <span className="cl-rank">{i === 0 ? "♛" : i + 1}</span>
                    <Link className="cl-name" href={`/members/${t.handle}`}>
                      {t.display_name}
                    </Link>
                    <b>
                      {t.best >= 6 ? `Master${t.clears > 1 ? ` ×${t.clears}` : ""}` : `${t.best} cut${t.best === 1 ? "" : "s"}`}
                    </b>
                  </li>
                ))}
                {katanaTop.length === 0 ? <li className="muted">No duels won yet. First blood is yours.</li> : null}
              </ol>
            </div>
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
