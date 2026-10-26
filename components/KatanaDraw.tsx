"use client";

import { useEffect, useRef, useState } from "react";
import { katanaEnd, katanaStart } from "@/app/(site)/account/actions";
import { lionSays } from "@/lib/lion";
import { KATANA_ENTRY, KATANA_FEINT_FROM, KATANA_ORDER, KATANA_PRIZES, KATANA_REACT } from "@/lib/katana";
import { ANIM, type Boss, DEFAULT_SKIN, skinById } from "@/lib/pinrun";

type Phase = "intro" | "wait" | "draw" | "won" | "lost" | "between" | "done";
type Result = { you: number | null; them: number; why: "win" | "early" | "slow" };

const rand = (a: number, b: number) => a + Math.random() * (b - a);

/**
 * KATANA DRAW: a samurai quick-draw ladder against real Risers. Wait for the signal, then tap
 * before they draw. Tapping early (or on a feint) loses. Pay Temple coins to enter, cash out any
 * time; lose a duel and the pot is gone.
 */
export function KatanaDraw({ loggedIn, coins: initialCoins, bosses, skin = DEFAULT_SKIN }: { loggedIn: boolean; coins: number | null; bosses: Boss[]; skin?: string }) {
  // the ladder: Risers with art, easiest to hardest (Erick last)
  const pool = bosses.filter((b) => b.art);
  const ladder = KATANA_ORDER.map((id) => pool.find((b) => b.id === id)).filter((b): b is Boss => !!b);
  while (ladder.length < KATANA_REACT.length && pool.length) ladder.push(pool[ladder.length % pool.length]);
  const rungs = Math.min(ladder.length, KATANA_REACT.length);

  const [phase, setPhase] = useState<Phase>("intro");
  const phaseRef = useRef<Phase>("intro");
  const [rung, setRung] = useState(0);
  const [wins, setWins] = useState(0);
  const [practice, setPractice] = useState(false);
  const [coins, setCoins] = useState(initialCoins);
  const [result, setResult] = useState<Result | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [feint, setFeint] = useState(false);
  const stage = useRef<HTMLDivElement>(null);
  const timers = useRef<ReturnType<typeof setTimeout>[]>([]);
  const signalAt = useRef(0);
  const oppMs = useRef(0);
  const audio = useRef<AudioContext | null>(null);
  const lion = skinById(skin) ?? skinById(DEFAULT_SKIN)!;
  // timers fire long after the render that set them up: read live values from refs
  const live = useRef({ runId: null as number | null, wins: 0, practice: false, rung: 0 });
  /** Result buttons ignore taps for a moment (on touch, the drawing tap can land on them). */
  const [settled, setSettled] = useState(true);
  const settle = useRef<ReturnType<typeof setTimeout> | null>(null);
  const go = (p: Phase) => {
    phaseRef.current = p;
    setPhase(p);
    if (settle.current) clearTimeout(settle.current);
    setSettled(p === "intro");
    if (p !== "intro") settle.current = setTimeout(() => setSettled(true), 550);
  };
  const clear = () => {
    for (const t of timers.current) clearTimeout(t);
    timers.current = [];
  };
  useEffect(() => clear, []);

  const tone = (f: number, d = 0.12, type: OscillatorType = "square", vol = 0.05) => {
    try {
      audio.current ??= new AudioContext();
      const a = audio.current;
      const o = a.createOscillator();
      const g = a.createGain();
      o.type = type;
      o.frequency.setValueAtTime(f, a.currentTime);
      o.frequency.exponentialRampToValueAtTime(Math.max(40, f * 0.5), a.currentTime + d);
      g.gain.setValueAtTime(vol, a.currentTime);
      g.gain.exponentialRampToValueAtTime(0.0001, a.currentTime + d);
      o.connect(g).connect(a.destination);
      o.start();
      o.stop(a.currentTime + d);
    } catch {}
  };

  const duel = (r: number) => {
    clear();
    live.current.rung = r;
    setRung(r);
    setResult(null);
    setFeint(false);
    go("wait");
    const wait = rand(1700, 3900);
    // feints: a twitch and a grey "!" before the real thing (tap on one and you've lost)
    const nFeints = r >= rungs - 1 ? 2 : r >= KATANA_FEINT_FROM && Math.random() < 0.55 ? 1 : 0;
    for (let i = 0; i < nFeints; i++) {
      const at = rand(500, wait - 450);
      timers.current.push(
        setTimeout(() => {
          setFeint(true);
          tone(260, 0.08, "triangle", 0.04);
          timers.current.push(setTimeout(() => setFeint(false), 260));
        }, at),
      );
    }
    timers.current.push(
      setTimeout(() => {
        setFeint(false);
        go("draw");
        // timestamp the signal on the frame it shows
        requestAnimationFrame(() => {
          signalAt.current = performance.now();
          oppMs.current = KATANA_REACT[r] + rand(-25, 25);
          tone(880, 0.25, "sawtooth", 0.07);
          timers.current.push(setTimeout(() => lose(null, "slow"), oppMs.current));
        });
      }, wait),
    );
  };

  const lose = (you: number | null, why: "early" | "slow") => {
    if (phaseRef.current !== "wait" && phaseRef.current !== "draw") return;
    clear();
    const L = live.current;
    setResult({ you, them: Math.round(oppMs.current || KATANA_REACT[L.rung]), why });
    go("lost");
    tone(120, 0.5, "sawtooth", 0.07);
    if (!L.practice && L.runId !== null) {
      katanaEnd(L.runId, L.wins, false)
        .then((r) => r.coins !== null && setCoins(r.coins))
        .catch(() => {});
      L.runId = null;
    }
  };

  const win = (you: number) => {
    clear();
    const n = live.current.wins + 1;
    live.current.wins = n;
    setWins(n);
    setResult({ you, them: Math.round(oppMs.current), why: "win" });
    go("won");
    tone(1400, 0.08, "square", 0.05);
    setTimeout(() => tone(700, 0.3, "triangle", 0.05), 60);
    timers.current.push(
      setTimeout(() => {
        if (n >= rungs) finish(n, true);
        else go("between");
      }, 1300),
    );
  };

  const tap = (t: number) => {
    const p = phaseRef.current;
    if (p === "wait") lose(null, "early");
    else if (p === "draw" && signalAt.current) {
      const you = Math.max(0, t - signalAt.current);
      if (you < oppMs.current) win(Math.round(you));
      else lose(Math.round(you), "slow");
    }
  };

  const begin = async (asPractice: boolean) => {
    setMsg(null);
    setWins(0);
    setPractice(asPractice);
    live.current = { runId: null, wins: 0, practice: asPractice, rung: 0 };
    if (!asPractice) {
      setBusy(true);
      try {
        const r = await katanaStart();
        setBusy(false);
        if (r.coins !== null) setCoins(r.coins);
        if (!r.ok || r.runId === null) {
          setMsg(r.message);
          return;
        }
        live.current.runId = r.runId;
      } catch {
        setBusy(false);
        setMsg("Couldn't start. Check your connection.");
        return;
      }
    }
    signalAt.current = 0;
    duel(0);
  };

  const finish = async (n: number, cash: boolean) => {
    clear();
    go("done");
    const L = live.current;
    if (L.practice || L.runId === null) return;
    const id = L.runId;
    L.runId = null;
    setBusy(true);
    try {
      const r = await katanaEnd(id, n, cash);
      if (r.coins !== null) setCoins(r.coins);
      if (r.paid) {
        setMsg(`Cashed out ${r.paid.toLocaleString("en-AU")} Temple coins.`);
        if (n >= rungs) lionSays("roar", `ROAR! Katana Master: +${r.paid} Temple coins!`);
      }
    } catch {
      setMsg("Couldn't cash out. Check your connection.");
    }
    setBusy(false);
  };

  const opp = ladder[rung];
  const oppName = opp ? opp.name.split(" ")[0] : "Riser";
  const pot = KATANA_PRIZES[wins];
  const next = KATANA_PRIZES[Math.min(wins + 1, KATANA_PRIZES.length - 1)];
  const stop = (e: React.SyntheticEvent) => e.stopPropagation();

  if (!rungs) return null;

  return (
    <div className="katana">
      <div
        ref={stage}
        className={`kd-stage kd-${phase}${feint ? " kd-feint" : ""}`}
        tabIndex={0}
        onPointerDown={(e) => {
          if (phaseRef.current === "wait" || phaseRef.current === "draw") {
            e.preventDefault();
            tap(e.timeStamp);
          }
        }}
        onKeyDown={(e) => {
          if (e.code !== "Space" && e.code !== "Enter") return;
          // keep the key to this game (Pin Run listens for Space too)
          e.stopPropagation();
          if (phaseRef.current === "wait" || phaseRef.current === "draw") {
            e.preventDefault();
            if (!e.repeat) tap(e.timeStamp);
          }
        }}
        aria-label="Katana Draw: tap when you see DRAW"
      >
        {/* the ladder */}
        <ol className="kd-ladder" aria-label="The ladder">
          {ladder.slice(0, rungs).map((b, i) => (
            <li key={`${b.id}-${i}`} className={i < wins ? "beat" : i === rung && phase !== "intro" ? "now" : undefined} title={b.name}>
              <span style={{ backgroundImage: `url(${b.art})` }} />
            </li>
          ))}
        </ol>
        <div className="kd-you" aria-hidden>
          <div
            className="kd-lion"
            style={{ backgroundImage: `url(/pinrun/anim/${lion.id}.webp)`, aspectRatio: `${lion.anim.w} / ${ANIM.h}`, backgroundSize: `${lion.anim.frames * 100}% 100%` }}
          />
        </div>
        <div className="kd-them" aria-hidden>
          {opp?.art ? <div className="kd-art" style={{ backgroundImage: `url(${opp.art})` }} /> : null}
        </div>
        <div className="kd-slash" aria-hidden />

        <div className="kd-center">
          {phase === "intro" ? (
            <div className="kd-card" onPointerDown={stop}>
              <p className="eyebrow">88 Risers arcade</p>
              <h3>
                Katana <span className="gold-text">Draw</span>
              </h3>
              <p>
                Stare them down. When <b>DRAW!</b> flashes, tap before they cut. Tap early, or on a feint, and you&apos;re done. Beat {rungs} Risers in a row, Erick last.
              </p>
              <p className="kd-prizes">
                Entry <b>{KATANA_ENTRY}</b> Temple coins · cash out after any win:{" "}
                {KATANA_PRIZES.slice(1, rungs + 1).map((p, i) => (
                  <span key={i}>
                    {i + 1}: <b>{p.toLocaleString("en-AU")}</b>
                    {i < rungs - 1 ? " · " : ""}
                  </span>
                ))}
              </p>
              <div className="kd-btns">
                {loggedIn ? (
                  <button type="button" className="btn btn-primary" disabled={busy || (coins ?? 0) < KATANA_ENTRY} onClick={() => begin(false)}>
                    {busy ? "…" : `Duel · ${KATANA_ENTRY} coins`}
                  </button>
                ) : null}
                <button type="button" className="btn btn-ghost" onClick={() => begin(true)}>
                  Practice (free)
                </button>
              </div>
              {loggedIn ? (
                <p className="kd-bal">
                  <span className="coin" aria-hidden /> {(coins ?? 0).toLocaleString("en-AU")} Temple coins
                </p>
              ) : (
                <p className="kd-bal">
                  <a href="/account?next=/play">Log in</a> to duel for Temple coins (earned in Pin Run).
                </p>
              )}
              {msg ? <p className="kd-msg">{msg}</p> : null}
            </div>
          ) : null}

          {phase === "wait" ? (
            <p className="kd-call">
              <small>
                Duel {rung + 1} of {rungs} · vs {oppName}
              </small>
              {feint ? "!" : "Steady…"}
            </p>
          ) : null}
          {phase === "draw" ? <p className="kd-call kd-go">DRAW!</p> : null}

          {phase === "won" && result ? (
            <p className="kd-call kd-good">
              CUT!
              <small>
                You {result.you}ms · {oppName} {result.them}ms
              </small>
            </p>
          ) : null}

          {phase === "between" ? (
            <div className="kd-card" onPointerDown={stop}>
              <p className="eyebrow">
                {wins} down · {rungs - wins} to go
              </p>
              <h3>{oppName} is cut.</h3>
              <p>
                Next: <b>{ladder[wins]?.name}</b>, who draws faster{wins + 1 >= KATANA_FEINT_FROM + 1 ? " and feints" : ""}.
              </p>
              <div className="kd-btns">
                <button type="button" className="btn btn-primary" disabled={!settled} onClick={() => duel(wins)}>
                  Next duel{practice ? "" : ` · pot ${next.toLocaleString("en-AU")}`}
                </button>
                {!practice ? (
                  <button type="button" className="btn btn-ghost" disabled={busy || !settled} onClick={() => finish(wins, true)}>
                    Cash out {pot.toLocaleString("en-AU")}
                  </button>
                ) : (
                  <button type="button" className="btn btn-ghost" disabled={!settled} onClick={() => finish(wins, false)}>
                    Stop
                  </button>
                )}
              </div>
            </div>
          ) : null}

          {phase === "lost" && result ? (
            <div className="kd-card" onPointerDown={stop}>
              <p className="eyebrow">Duel {rung + 1}</p>
              <h3 className="kd-bad">{result.why === "early" ? (feint ? "Feinted!" : "Too early!") : `${oppName} cuts you.`}</h3>
              <p>
                {result.why === "early"
                  ? "You drew before the signal."
                  : result.you !== null
                    ? `You ${result.you}ms · ${oppName} ${result.them}ms.`
                    : `${oppName} drew in ${result.them}ms.`}{" "}
                {!practice && wins > 0 ? `The ${KATANA_PRIZES[wins].toLocaleString("en-AU")} pot is gone.` : ""}
              </p>
              <div className="kd-btns">
                <button type="button" className="btn btn-primary" disabled={!settled} onClick={() => go("intro")}>
                  Run it back
                </button>
              </div>
            </div>
          ) : null}

          {phase === "done" ? (
            <div className="kd-card" onPointerDown={stop}>
              {wins >= rungs ? (
                <>
                  <img className="kd-katana" src="/chalk/katana.webp" alt="The 88 Risers katana" />
                  <h3>
                    Katana <span className="gold-text">Master</span>
                  </h3>
                  <p>You cut all {rungs}, Erick included.</p>
                </>
              ) : (
                <h3>{wins ? `${wins} cut${wins === 1 ? "" : "s"}.` : "Done."}</h3>
              )}
              {msg ? <p className="kd-msg ok">{msg}</p> : practice ? <p>Practice run: no coins in or out.</p> : null}
              <div className="kd-btns">
                <button type="button" className="btn btn-primary" disabled={busy || !settled} onClick={() => go("intro")}>
                  Again
                </button>
              </div>
            </div>
          ) : null}
        </div>
        {phase !== "intro" && !practice ? (
          <p className="kd-pot">
            Pot <b>{pot.toLocaleString("en-AU")}</b>
          </p>
        ) : null}
      </div>
    </div>
  );
}
