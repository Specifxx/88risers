"use client";

import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { buySkin, equipSkin, submitScore } from "@/app/(site)/account/actions";
import { lionSays } from "@/lib/lion";
import { ANIM, DEFAULT_SKIN, SKINS, type Wallet, skinById } from "@/lib/pinrun";
import { drawAura, drawFx, newFx, stepFx } from "@/lib/pinrun-fx";

/**
 * PIN RUN — a one-button arm wrestling platformer.
 * Auto-run across floating arm wrestling tables. Tap to jump (tap again in the air to double jump,
 * hold for height). Run into a rival and it's a grip fight: tap when the needle is in the gold zone
 * to PIN them and get launched; miss and you lose a heart. Chain pins for a combo multiplier.
 * Coins grabbed in a run are banked as Temple coins and spent on lion skins in the Lion Temple.
 */

const W = 960;
const H = 540;
const G = 2300; // gravity px/s²
const JUMP = 820;
const JUMP2 = 720;
const PX = 230; // player screen x
const R = 26; // player hit radius
/** Run-cycle frames per second at the base speed (the video was 24fps); scales with run speed. */
const ANIM_FPS = 24;

type Plat = { x: number; w: number; y: number; rival: Rival | null };
type Rival = { x: number; state: "idle" | "pinned" | "gone"; vy: number; y: number; vx: number; spin: number };
type Coin = { x: number; y: number; got: boolean };
type Particle = { x: number; y: number; vx: number; vy: number; life: number; c: string; s: number };
type Pop = { x: number; y: number; t: string; life: number; c: string };

interface World {
  t: number;
  dist: number;
  speed: number;
  boost: number;
  y: number;
  vy: number;
  ground: Plat | null;
  coyote: number;
  jumps: number;
  holding: boolean;
  hearts: number;
  invuln: number;
  score: number;
  coins: number;
  pins: number;
  combo: number;
  plats: Plat[];
  coinsList: Coin[];
  parts: Particle[];
  pops: Pop[];
  shake: number;
  duel: null | { rival: Rival; plat: Plat; t: number; zone: number; width: number; speed: number; result: null | "pin" | "miss"; rt: number };
  over: boolean;
  runFrame: number;
  /** Landing squash timer. */
  land: number;
}

const rand = (a: number, b: number) => a + Math.random() * (b - a);

function newWorld(): World {
  const first: Plat = { x: -200, w: 900, y: 400, rival: null };
  return {
    t: 0,
    dist: 0,
    speed: 330,
    boost: 0,
    y: first.y - R,
    vy: 0,
    ground: first,
    coyote: 0,
    jumps: 0,
    holding: false,
    hearts: 3,
    invuln: 0,
    score: 0,
    coins: 0,
    pins: 0,
    combo: 1,
    plats: [first],
    coinsList: [],
    parts: [],
    pops: [],
    shake: 0,
    duel: null,
    over: false,
    runFrame: 0,
    land: 0,
  };
}

function extend(w: World) {
  let last = w.plats[w.plats.length - 1];
  while (last.x + last.w < w.dist + W * 2) {
    const level = Math.min(1, w.dist / 30000);
    // Tuned for the lion's size: shorter tables, bigger steps and gaps than the original circle needed.
    const gap = rand(100, 165 + level * 130) * (w.speed / 330);
    const width = rand(175, 340) - level * 70;
    const y = Math.max(235, Math.min(460, last.y + rand(-140, 125)));
    const x = last.x + last.w + gap;
    const n = w.plats.length;
    const rivalChance = n < 4 ? 0 : 0.32 + level * 0.25;
    const p: Plat = { x, w: width, y, rival: null };
    if (Math.random() < rivalChance && width > 200) p.rival = { x: x + width * rand(0.45, 0.7), state: "idle", vy: 0, y: 0, vx: 0, spin: 0 };
    w.plats.push(p);
    // a little arc of coins over the gap or the table
    if (Math.random() < 0.7) {
      const cx = Math.random() < 0.5 ? x - gap / 2 : x + width * 0.3;
      const k = Math.random() < 0.5 ? 3 : 5;
      for (let i = 0; i < k; i++) w.coinsList.push({ x: cx + (i - (k - 1) / 2) * 34, y: y - 110 - Math.sin((i / (k - 1)) * Math.PI) * 50, got: false });
    }
    last = p;
  }
  w.plats = w.plats.filter((p) => p.x + p.w > w.dist - 400);
  w.coinsList = w.coinsList.filter((c) => c.x > w.dist - 400);
}

export function PinRun({ loggedIn, best: initialBest, wallet: initialWallet }: { loggedIn: boolean; best: number | null; wallet: Wallet | null }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const world = useRef<World>(newWorld());
  const [phase, setPhase] = useState<"title" | "play" | "over">("title");
  const phaseRef = useRef(phase);
  const [final, setFinal] = useState({ score: 0, pins: 0, coins: 0 });
  const [best, setBest] = useState<number | null>(initialBest);
  const [saveMsg, setSaveMsg] = useState<string | null>(null);
  const [muted, setMuted] = useState(false);
  const mutedRef = useRef(false);
  const audio = useRef<AudioContext | null>(null);
  const overAt = useRef(0);
  const imgs = useRef<{ skin?: HTMLImageElement; cloud?: HTMLImageElement; ring?: HTMLImageElement }>({});
  const [wallet, setWallet] = useState<Wallet | null>(initialWallet);
  const [temple, setTemple] = useState(false);
  const templeRef = useRef(false);
  templeRef.current = temple;
  const skin = wallet?.skin ?? DEFAULT_SKIN;
  const anim = useRef(skinById(DEFAULT_SKIN)!.anim);
  const skinRef = useRef(skin);
  skinRef.current = skin;
  const fx = useRef(newFx());

  phaseRef.current = phase;
  mutedRef.current = muted;

  const beep = (f: number, d = 0.08, type: OscillatorType = "square", vol = 0.05) => {
    if (mutedRef.current) return;
    try {
      audio.current ??= new AudioContext();
      const a = audio.current;
      const o = a.createOscillator();
      const g = a.createGain();
      o.type = type;
      o.frequency.setValueAtTime(f, a.currentTime);
      o.frequency.exponentialRampToValueAtTime(Math.max(40, f * 0.6), a.currentTime + d);
      g.gain.setValueAtTime(vol, a.currentTime);
      g.gain.exponentialRampToValueAtTime(0.0001, a.currentTime + d);
      o.connect(g).connect(a.destination);
      o.start();
      o.stop(a.currentTime + d);
    } catch {}
  };

  const start = () => {
    world.current = newWorld();
    extend(world.current);
    setSaveMsg(null);
    setPhase("play");
  };

  // One input does everything: start, jump, double jump, grip.
  const press = () => {
    const w = world.current;
    if (phaseRef.current === "title") return start();
    if (phaseRef.current === "over") {
      if (performance.now() - overAt.current > 900) start();
      return;
    }
    if (w.duel) {
      if (w.duel.result) return;
      const needle = (Math.sin(w.duel.t * w.duel.speed) + 1) / 2;
      const hit = Math.abs(needle - w.duel.zone) < w.duel.width / 2;
      w.duel.result = hit ? "pin" : "miss";
      w.duel.rt = 0;
      return;
    }
    w.holding = true;
    if (w.ground || w.coyote > 0) {
      w.vy = -JUMP;
      w.ground = null;
      w.coyote = 0;
      w.jumps = 1;
      beep(520, 0.09);
    } else if (w.jumps < 2) {
      w.vy = -JUMP2;
      w.jumps = 2;
      beep(700, 0.09);
      for (let i = 0; i < 8; i++) w.parts.push({ x: w.dist + PX, y: w.y + R, vx: rand(-120, 120), vy: rand(40, 160), life: 0.4, c: "#efe7d6", s: 3 });
    }
  };
  const release = () => {
    world.current.holding = false;
  };

  useEffect(() => {
    const cloud = new Image();
    cloud.src = "/ink/cloud.webp";
    const ring = new Image();
    ring.src = "/ink/circle.webp";
    imgs.current = { ...imgs.current, cloud, ring };

    const key = (e: KeyboardEvent) => {
      if (templeRef.current) {
        if (e.code === "Escape") setTemple(false);
        return;
      }
      if (["Space", "ArrowUp", "KeyW", "Enter"].includes(e.code)) {
        e.preventDefault();
        if (e.type === "keydown" && !e.repeat) press();
        if (e.type === "keyup") release();
      }
    };
    window.addEventListener("keydown", key);
    window.addEventListener("keyup", key);
    return () => {
      window.removeEventListener("keydown", key);
      window.removeEventListener("keyup", key);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // The equipped lion.
  useEffect(() => {
    const img = new Image();
    img.src = `/pinrun/anim/${skin}.webp`;
    imgs.current = { ...imgs.current, skin: img };
    anim.current = (skinById(skin) ?? skinById(DEFAULT_SKIN)!).anim;
  }, [skin]);

  useEffect(() => {
    const cv = canvas.current;
    if (!cv) return;
    const ctx = cv.getContext("2d")!;
    let raf = 0;
    let lastT = performance.now();

    const endGame = () => {
      const w = world.current;
      w.over = true;
      const score = Math.floor(w.score);
      setFinal({ score, pins: w.pins, coins: w.coins });
      setPhase("over");
      overAt.current = performance.now();
      beep(160, 0.5, "sawtooth", 0.06);
      if (loggedIn) {
        submitScore(score, w.coins).then((r) => {
          if (r.best !== null) setBest(r.best);
          if (r.wallet) setWallet(r.wallet);
          setSaveMsg([r.message, r.saved ? `+${r.saved} Temple coins banked.` : ""].filter(Boolean).join(" "));
          if (r.coins) lionSays("cheer", `+${r.coins} coins for today's run!`);
        });
      } else setBest((b) => Math.max(b ?? 0, score));
    };

    const step = (dt: number) => {
      const w = world.current;
      w.t += dt;
      if (w.duel) {
        const d = w.duel;
        d.t += dt;
        if (!d.result && d.t > 2.4) {
          d.result = "miss";
          d.rt = 0;
        }
        if (d.result) {
          d.rt += dt;
          if (d.rt > 0.55) {
            if (d.result === "pin") {
              w.pins++;
              const gain = 100 * w.combo;
              w.score += gain;
              w.pops.push({ x: w.dist + PX, y: w.y - 70, t: `PIN! +${gain}`, life: 1.1, c: "#f2e1b6" });
              w.combo = Math.min(8, w.combo + 1);
              d.rival.state = "pinned";
              d.rival.vx = 520;
              d.rival.vy = -700;
              w.vy = -1000;
              w.ground = null;
              w.jumps = 1;
              w.boost = 1.6;
              w.shake = 0.35;
              beep(880, 0.12, "square", 0.06);
              setTimeout(() => beep(1320, 0.16, "square", 0.06), 90);
              for (let i = 0; i < 26; i++)
                w.parts.push({ x: d.rival.x, y: d.plat.y - 30, vx: rand(-320, 320), vy: rand(-420, 60), life: rand(0.4, 0.9), c: i % 3 ? "#d5b67a" : "#ff4a4f", s: rand(2, 5) });
            } else {
              w.hearts--;
              w.combo = 1;
              w.invuln = 1.2;
              w.pops.push({ x: w.dist + PX, y: w.y - 70, t: "SLIPPED!", life: 1, c: "#ff4a4f" });
              d.rival.state = "gone";
              w.vy = -420;
              w.ground = null;
              w.shake = 0.3;
              beep(200, 0.25, "sawtooth", 0.06);
              if (w.hearts <= 0) return endGame();
            }
            w.duel = null;
          }
        }
        return;
      }

      const speed = (w.speed + Math.min(330, w.dist / 90)) * (w.boost > 0 ? 1.35 : 1);
      w.boost = Math.max(0, w.boost - dt);
      w.invuln = Math.max(0, w.invuln - dt);
      w.dist += speed * dt;
      w.score += speed * dt * 0.05;
      w.runFrame += dt * speed * 0.03;
      extend(w);

      // vertical
      const prevBottom = w.y + R;
      w.vy += G * dt * (!w.holding && w.vy < 0 ? 1.9 : 1);
      w.y += w.vy * dt;
      const px = w.dist + PX;
      if (w.ground && (px > w.ground.x + w.ground.w + 8 || px < w.ground.x - 8)) {
        w.ground = null;
        w.coyote = 0.09;
        w.jumps = 1;
      }
      w.coyote = Math.max(0, w.coyote - dt);
      if (!w.ground && w.vy >= 0) {
        for (const p of w.plats) {
          if (px > p.x - 6 && px < p.x + p.w + 6 && prevBottom <= p.y + 4 && w.y + R >= p.y) {
            w.y = p.y - R;
            w.vy = 0;
            w.ground = p;
            w.jumps = 0;
            w.land = 0.16;
            for (let i = 0; i < 6; i++) w.parts.push({ x: px, y: p.y, vx: rand(-90, 90), vy: rand(-140, -40), life: 0.35, c: "#efe7d6", s: 2.5 });
            break;
          }
        }
      }
      if (w.ground) w.y = w.ground.y - R;

      // rivals: touching one starts a grip fight
      for (const p of w.plats) {
        const r = p.rival;
        if (!r) continue;
        if (r.state === "pinned") {
          r.vy += G * dt;
          r.y += r.vy * dt;
          r.x += r.vx * dt;
          r.spin += dt * 9;
          continue;
        }
        if (r.state === "idle" && w.invuln === 0 && Math.abs(px - r.x) < R + 14 && w.y + R > p.y - 70) {
          const level = Math.min(1, w.dist / 30000);
          w.duel = { rival: r, plat: p, t: 0, zone: rand(0.25, 0.75), width: 0.24 - level * 0.12, speed: 4.2 + level * 3.5, result: null, rt: 0 };
          beep(330, 0.12, "triangle", 0.06);
          return;
        }
      }

      // coins
      for (const c of w.coinsList) {
        // close to the original hit circle: paws to chest, not the whole mane
        if (!c.got && Math.abs(c.x - px) < 32 && c.y > w.y + R - 78 && c.y < w.y + R + 8) {
          c.got = true;
          w.coins++;
          w.score += 10 * w.combo;
          beep(1180, 0.05, "square", 0.035);
        }
      }

      // fell into the chalk pit
      if (w.y > H + 80) {
        w.hearts--;
        w.combo = 1;
        w.shake = 0.3;
        beep(150, 0.3, "sawtooth", 0.06);
        if (w.hearts <= 0) return endGame();
        const next = w.plats.find((p) => p.x + p.w > px + 40) ?? w.plats[w.plats.length - 1];
        w.dist = Math.max(w.dist, next.x - PX + 20);
        if (next.rival && next.rival.state === "idle") next.rival.state = "gone";
        w.y = next.y - R - 120;
        w.vy = 0;
        w.ground = null;
        w.invuln = 1.2;
      }

      for (const p of w.parts) {
        p.x += p.vx * dt;
        p.y += p.vy * dt;
        p.vy += 900 * dt;
        p.life -= dt;
      }
      w.parts = w.parts.filter((p) => p.life > 0);
      for (const p of w.pops) {
        p.y -= 50 * dt;
        p.life -= dt;
      }
      w.pops = w.pops.filter((p) => p.life > 0);
      w.shake = Math.max(0, w.shake - dt);
      w.land = Math.max(0, w.land - dt);
    };

    const drawTable = (p: Plat, cam: number) => {
      const x = p.x - cam;
      // legs + brace
      ctx.fillStyle = "#1b1814";
      ctx.fillRect(x + 16, p.y + 18, 10, H - p.y);
      ctx.fillRect(x + p.w - 26, p.y + 18, 10, H - p.y);
      ctx.fillRect(x + 16, p.y + 120, p.w - 32, 8);
      // padded top
      const g = ctx.createLinearGradient(0, p.y, 0, p.y + 22);
      g.addColorStop(0, "#2a251d");
      g.addColorStop(1, "#100e0b");
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.roundRect(x, p.y, p.w, 22, 6);
      ctx.fill();
      ctx.fillStyle = "#d5b67a";
      ctx.fillRect(x + 4, p.y, p.w - 8, 3);
      // pin pads + grip pegs at the ends
      ctx.fillStyle = "#0a0908";
      ctx.fillRect(x + 6, p.y - 16, 12, 16);
      ctx.fillRect(x + p.w - 18, p.y - 16, 12, 16);
      ctx.fillStyle = "#a69d8b";
      ctx.fillRect(x + 24, p.y - 26, 5, 26);
      ctx.fillRect(x + p.w - 29, p.y - 26, 5, 26);
    };

    const drawRival = (r: Rival, p: Plat, cam: number) => {
      if (r.state === "gone") return;
      const x = r.x - cam;
      const base = r.state === "pinned" ? p.y + r.y : p.y;
      ctx.save();
      ctx.translate(x, base);
      if (r.state === "pinned") ctx.rotate(r.spin);
      ctx.fillStyle = "#14110e";
      ctx.strokeStyle = "#d42a2f";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.roundRect(-14, -62, 28, 44, 8);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = "#d42a2f";
      ctx.fillRect(-14, -46, 28, 5);
      ctx.fillStyle = "#14110e";
      ctx.beginPath();
      ctx.arc(0, -76, 13, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      // raised arm, ready to grip
      ctx.strokeStyle = "#14110e";
      ctx.lineWidth = 9;
      ctx.lineCap = "round";
      ctx.beginPath();
      ctx.moveTo(-10, -50);
      ctx.lineTo(-30, -40);
      ctx.lineTo(-34, -64);
      ctx.stroke();
      ctx.fillStyle = "#ff4a4f";
      ctx.font = "700 11px system-ui";
      ctx.textAlign = "center";
      if (r.state === "idle") ctx.fillText("!", 0, -96);
      ctx.restore();
    };

    /** The lion: its AI-animated run cycle, played at a rate that follows the run speed. */
    let frameAt = 0;
    const drawPlayer = (w: World) => {
      if (w.invuln > 0 && Math.floor(w.t * 14) % 2 === 0) return;
      const x = PX;
      const feet = w.y + R;
      const onGround = !!w.ground;
      const { frames, w: fw } = anim.current;
      // on the table the stride runs with the speed; in the air it holds the leap
      if (onGround || frameAt === 0) frameAt = Math.floor(w.runFrame * (ANIM_FPS / 9.9)) % frames;
      const tilt = onGround ? 0 : Math.max(-0.2, Math.min(0.16, w.vy / 3200));
      const squash = w.land / 0.16;
      const sy = onGround ? 1 - squash * 0.08 : w.vy < 0 ? 1.04 : 1;
      const sx = onGround ? 1 + squash * 0.05 : w.vy < 0 ? 0.97 : 1;

      if (w.boost > 0) {
        ctx.strokeStyle = "rgba(255,74,79,.55)";
        ctx.lineWidth = 3;
        ctx.lineCap = "round";
        for (let i = 1; i < 4; i++) {
          ctx.beginPath();
          ctx.moveTo(x - 60 - i * 12, feet - 30 - i * 12);
          ctx.lineTo(x - 60 - i * 12 - 34, feet - 30 - i * 12);
          ctx.stroke();
        }
      }
      if (onGround) {
        ctx.fillStyle = "rgba(0,0,0,.35)";
        ctx.beginPath();
        ctx.ellipse(x, feet + 1, 52, 5, 0, 0, Math.PI * 2);
        ctx.fill();
      }
      const img = imgs.current.skin;
      ctx.save();
      ctx.translate(x, feet);
      ctx.rotate(tilt);
      ctx.scale(sx, sy);
      if (img?.complete && img.naturalWidth) {
        const k = ANIM.scale;
        ctx.drawImage(img, frameAt * fw, 0, fw, ANIM.h, -ANIM.ax * k, -ANIM.h * k, fw * k, ANIM.h * k);
      } else {
        ctx.fillStyle = "#d5b67a";
        ctx.beginPath();
        ctx.arc(0, -R, R, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    };

    const drawDuel = (w: World) => {
      const d = w.duel!;
      ctx.fillStyle = "rgba(8,7,6,.55)";
      ctx.fillRect(0, 0, W, H);
      const cx = W / 2;
      const cy = 150;
      ctx.fillStyle = "rgba(16,14,11,.94)";
      ctx.strokeStyle = d.result === "pin" ? "#d5b67a" : d.result === "miss" ? "#d42a2f" : "rgba(213,182,122,.4)";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.roundRect(cx - 310, cy - 100, 620, 360, 22);
      ctx.fill();
      ctx.stroke();
      ctx.textAlign = "center";
      ctx.fillStyle = "#efe7d6";
      ctx.font = "900 46px 'Saira Extra Condensed', Impact, sans-serif";
      ctx.fillText(d.result === "pin" ? "PIN!" : d.result === "miss" ? "SLIPPED!" : "GRIP FIGHT", cx, cy - 40);
      ctx.font = "700 14px 'Chakra Petch', monospace";
      ctx.fillStyle = "#d5b67a";
      if (!d.result) ctx.fillText("TAP WHEN THE NEEDLE HITS GOLD", cx, cy - 12);
      const bw = 520;
      const bx = cx - bw / 2;
      const by = cy + 10;
      ctx.fillStyle = "#16130f";
      ctx.beginPath();
      ctx.roundRect(bx, by, bw, 30, 15);
      ctx.fill();
      ctx.fillStyle = "#d5b67a";
      ctx.fillRect(bx + bw * (d.zone - d.width / 2), by + 3, bw * d.width, 24);
      const needle = (Math.sin(d.t * d.speed) + 1) / 2;
      const nx = bx + bw * needle;
      ctx.fillStyle = d.result === "pin" ? "#f2e1b6" : d.result === "miss" ? "#ff4a4f" : "#ffffff";
      ctx.fillRect(nx - 3, by - 8, 6, 46);
      // the grip: two forearms meeting
      const tilt = d.result === "pin" ? -0.9 * Math.min(1, d.rt * 4) : d.result === "miss" ? 0.9 * Math.min(1, d.rt * 4) : Math.sin(d.t * 18) * 0.06;
      ctx.save();
      ctx.translate(cx, by + 150);
      ctx.rotate(tilt);
      ctx.strokeStyle = "#d5b67a";
      ctx.lineWidth = 22;
      ctx.lineCap = "round";
      ctx.beginPath();
      ctx.moveTo(-6, 0);
      ctx.lineTo(-6, -80);
      ctx.stroke();
      ctx.strokeStyle = "#3a332a";
      ctx.beginPath();
      ctx.moveTo(6, 0);
      ctx.lineTo(6, -80);
      ctx.stroke();
      ctx.fillStyle = "#efe7d6";
      ctx.beginPath();
      ctx.arc(0, -86, 16, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
      ctx.fillStyle = "#1f1b15";
      ctx.fillRect(cx - 140, by + 150, 280, 14);
    };

    const draw = () => {
      const w = world.current;
      const cam = w.dist;
      ctx.save();
      if (w.shake > 0) ctx.translate(rand(-6, 6) * w.shake * 3, rand(-6, 6) * w.shake * 3);
      // sky
      const g = ctx.createLinearGradient(0, 0, 0, H);
      g.addColorStop(0, "#160d0c");
      g.addColorStop(0.6, "#0a0908");
      g.addColorStop(1, "#120a09");
      ctx.fillStyle = g;
      ctx.fillRect(-20, -20, W + 40, H + 40);
      // red sun ring, far parallax
      const ring = imgs.current.ring;
      if (ring?.complete) {
        ctx.globalAlpha = 0.35;
        ctx.drawImage(ring, W - 330 - ((cam * 0.02) % 40), 40, 260, 243);
        ctx.globalAlpha = 1;
      }
      // ink clouds, mid parallax
      const cloud = imgs.current.cloud;
      if (cloud?.complete) {
        ctx.globalAlpha = 0.22;
        for (let i = 0; i < 4; i++) {
          const x = ((i * 380 - cam * 0.15) % (W + 400) + W + 400) % (W + 400) - 200;
          ctx.drawImage(cloud, x, 60 + (i % 2) * 90, 220, 139);
        }
        ctx.globalAlpha = 1;
      }
      // chalk-pit haze
      const fog = ctx.createLinearGradient(0, H - 90, 0, H);
      fog.addColorStop(0, "rgba(212,42,47,0)");
      fog.addColorStop(1, "rgba(212,42,47,.25)");
      ctx.fillStyle = fog;
      ctx.fillRect(0, H - 90, W, 90);

      for (const p of w.plats) if (p.x - cam < W + 40 && p.x + p.w - cam > -40) drawTable(p, cam);
      for (const p of w.plats) if (p.rival) drawRival(p.rival, p, cam);
      for (const c of w.coinsList) {
        if (c.got) continue;
        const x = c.x - cam;
        if (x < -20 || x > W + 20) continue;
        const sq = Math.abs(Math.sin(w.t * 4 + c.x));
        ctx.fillStyle = "#d5b67a";
        ctx.beginPath();
        ctx.ellipse(x, c.y, 9 * sq + 2, 10, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = "#8d7448";
        ctx.fillRect(x - 1, c.y - 5, 2, 10);
      }
      for (const p of w.parts) {
        ctx.globalAlpha = Math.max(0, p.life * 2);
        ctx.fillStyle = p.c;
        ctx.fillRect(p.x - cam, p.y, p.s, p.s);
      }
      ctx.globalAlpha = 1;
      if (!(w.invuln > 0 && Math.floor(w.t * 14) % 2 === 0)) drawAura(ctx, skinRef.current, PX, w.y + R - 10, w.t);
      drawFx(ctx, fx.current, cam, "back");
      drawPlayer(w);
      drawFx(ctx, fx.current, cam, "front");
      ctx.textAlign = "center";
      ctx.font = "900 30px 'Saira Extra Condensed', Impact, sans-serif";
      for (const p of w.pops) {
        ctx.globalAlpha = Math.min(1, p.life * 2);
        ctx.fillStyle = p.c;
        ctx.fillText(p.t, p.x - cam, p.y);
      }
      ctx.globalAlpha = 1;
      ctx.restore();

      // HUD
      ctx.textAlign = "left";
      ctx.font = "900 34px 'Saira Extra Condensed', Impact, sans-serif";
      ctx.fillStyle = "#efe7d6";
      ctx.fillText(String(Math.floor(w.score)).padStart(6, "0"), 24, 46);
      ctx.font = "700 13px 'Chakra Petch', monospace";
      ctx.fillStyle = "#d5b67a";
      ctx.fillText(`PINS ${w.pins}   COINS ${w.coins}${w.combo > 1 ? `   COMBO x${w.combo}` : ""}`, 24, 68);
      for (let i = 0; i < 3; i++) {
        ctx.fillStyle = i < w.hearts ? "#d42a2f" : "#2a251d";
        ctx.beginPath();
        const hx = W - 40 - i * 30;
        ctx.arc(hx - 5, 36, 7, 0, Math.PI * 2);
        ctx.arc(hx + 5, 36, 7, 0, Math.PI * 2);
        ctx.moveTo(hx - 12, 39);
        ctx.lineTo(hx, 52);
        ctx.lineTo(hx + 12, 39);
        ctx.fill();
      }
      if (w.duel) drawDuel(w);
    };

    const loop = (now: number) => {
      const dt = Math.min(0.033, (now - lastT) / 1000);
      lastT = now;
      if (phaseRef.current === "play" && !world.current.over) step(dt);
      {
        const w = world.current;
        const moving = phaseRef.current === "play" && !w.over && !w.duel;
        // the run-cycle video already carries each lion's effects; the live particles trail behind it
        stepFx(fx.current, skinRef.current, w.dist + PX, w.y + R, dt, moving, 0.6);
      }
      draw();
      raf = requestAnimationFrame(loop);
    };
    extend(world.current);
    // Dev-only handle for automated play tests.
    if (process.env.NODE_ENV !== "production") (window as unknown as { __pinrun: typeof world }).__pinrun = world;
    raf = requestAnimationFrame(loop);
    const vis = () => {
      lastT = performance.now();
    };
    document.addEventListener("visibilitychange", vis);
    return () => {
      cancelAnimationFrame(raf);
      document.removeEventListener("visibilitychange", vis);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [loggedIn]);

  return (
    <div className="pinrun">
      <canvas
        ref={canvas}
        width={W}
        height={H}
        className="pinrun-canvas"
        onPointerDown={(e) => {
          e.preventDefault();
          press();
        }}
        onPointerUp={release}
        onPointerLeave={release}
        aria-label="Pin Run game. Press space or tap to jump and to grip."
      />
      {phase === "title" ? (
        <div className="pinrun-overlay" onPointerDown={start}>
          <p className="eyebrow">88 Risers arcade</p>
          <h2>
            PIN <span className="gold-text">RUN</span>
          </h2>
          <ul>
            <li>
              <b>Tap / Space</b> to jump. Tap again mid-air to double jump. Hold for height.
            </li>
            <li>
              <b>Hit a rival</b> and it&apos;s a grip fight: tap when the needle is in the <b className="gold-text">gold</b> to PIN and launch.
            </li>
            <li>Chain pins for a combo. Don&apos;t fall in the chalk pit.</li>
          </ul>
          <div className="pinrun-btns">
            <button type="button" className="btn btn-primary">
              Start
            </button>
            <TempleButton onOpen={() => setTemple(true)} coins={wallet?.coins ?? 0} loggedIn={loggedIn} />
          </div>
          {best ? <p className="pinrun-best">Your best: {best.toLocaleString("en-AU")}</p> : null}
        </div>
      ) : null}
      {phase === "over" ? (
        <div className="pinrun-overlay">
          <p className="eyebrow">Game over</p>
          <h2>{final.score.toLocaleString("en-AU")}</h2>
          <p className="pinrun-stats">
            {final.pins} pins · {final.coins} {final.coins === 1 ? "coin" : "coins"} grabbed
            {best ? ` · best ${best.toLocaleString("en-AU")}` : ""}
          </p>
          <div className="pinrun-btns">
            <button type="button" className="btn btn-primary pinrun-again" onClick={start}>
              ↻ Run it back
            </button>
            <TempleButton onOpen={() => setTemple(true)} coins={wallet?.coins ?? 0} loggedIn={loggedIn} />
          </div>
          <p className="pinrun-hint">or tap / press Space</p>
          {saveMsg ? <p className="pinrun-save">{saveMsg}</p> : null}
          {!loggedIn ? (
            <p className="pinrun-save">
              <a href="/account?next=/play">Create a free account</a> to save scores and keep the coins you grab for lion skins.
            </p>
          ) : null}
        </div>
      ) : null}
      <button type="button" className="pinrun-mute" onClick={() => setMuted((m) => !m)} aria-label={muted ? "Sound on" : "Sound off"}>
        {muted ? "♪̸" : "♪"}
      </button>
      {temple ? <LionTemple wallet={wallet} loggedIn={loggedIn} onWallet={setWallet} onClose={() => setTemple(false)} /> : null}
    </div>
  );
}

function TempleButton({ onOpen, coins, loggedIn }: { onOpen: () => void; coins: number; loggedIn: boolean }) {
  return (
    <button
      type="button"
      className="btn btn-ghost pinrun-temple-btn"
      // the title overlay starts a run on any press, so keep this one to ourselves
      onPointerDown={(e) => e.stopPropagation()}
      onClick={(e) => {
        e.stopPropagation();
        onOpen();
      }}
    >
      ⛩ <span className="pt-lion">Lion</span>Temple{loggedIn ? <span className="pinrun-temple-bal"> · {coins}</span> : null}
    </button>
  );
}

/** The Lion Temple: spend banked Temple coins on lion skins, and pick which one runs. */
function LionTemple({
  wallet,
  loggedIn,
  onWallet,
  onClose,
}: {
  wallet: Wallet | null;
  loggedIn: boolean;
  onWallet: (w: Wallet) => void;
  onClose: () => void;
}) {
  const [busy, setBusy] = useState<string | null>(null);
  const [msg, setMsg] = useState<{ text: string; ok: boolean } | null>(null);
  const coins = wallet?.coins ?? 0;
  const owned = new Set(wallet?.owned ?? [DEFAULT_SKIN]);
  const current = wallet?.skin ?? DEFAULT_SKIN;

  useEffect(() => {
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = prev;
    };
  }, []);

  const act = async (id: string, kind: "buy" | "equip") => {
    setBusy(id);
    setMsg(null);
    try {
      if (kind === "buy") {
        const r = await buySkin(id);
        if (r.wallet) onWallet(r.wallet);
        setMsg({ text: r.message, ok: r.ok });
        if (r.ok) lionSays("roar", `ROAR! ${skinById(id)?.name} unlocked.`);
      } else {
        const r = await equipSkin(id);
        if (r.wallet) onWallet(r.wallet);
      }
    } catch {
      setMsg({ text: "Something went wrong. Try again.", ok: false });
    }
    setBusy(null);
  };

  return createPortal(
    <div className="temple-backdrop" onPointerDown={onClose}>
      <div className="temple" role="dialog" aria-modal="true" aria-label="Lion Temple" onPointerDown={(e) => e.stopPropagation()}>
        <header className="temple-head">
          <div>
            <p className="eyebrow">Pin Run</p>
            <h2>
              <span aria-hidden>⛩</span> Lion <span className="gold-text">Temple</span>
            </h2>
            <p className="temple-sub">Every coin you grab in a run is banked here. Spend them on new lions.</p>
          </div>
          <div className="temple-bal">
            <span className="coin" aria-hidden /> <b>{coins}</b>
            <small>Temple coins</small>
          </div>
          <button type="button" className="temple-close" onClick={onClose} aria-label="Close the temple">
            ×
          </button>
        </header>
        {!loggedIn ? (
          <p className="temple-note">
            Playing as a guest: coins aren&apos;t kept. <a href="/account?next=/play">Make a free account</a> to bank them and unlock lions.
          </p>
        ) : null}
        {msg ? <p className={`temple-msg${msg.ok ? " ok" : ""}`}>{msg.text}</p> : null}
        <div className="temple-grid">
          {SKINS.map((k) => {
            const has = owned.has(k.id);
            const on = current === k.id;
            return (
              <article key={k.id} className={`temple-card${on ? " on" : ""}${has ? " owned" : ""}`}>
                <div className="temple-art">
                  {/* the lion's run cycle: a frame strip stepped through with CSS */}
                  <div
                    className="temple-run"
                    role="img"
                    aria-label={`${k.name} lion running`}
                    style={
                      {
                        backgroundImage: `url(/pinrun/anim/${k.id}.webp)`,
                        aspectRatio: `${k.anim.w} / ${ANIM.h}`,
                        "--n": k.anim.frames,
                      } as React.CSSProperties
                    }
                  />
                </div>
                <h3>{k.name}</h3>
                <p>{k.blurb}</p>
                <div className="temple-foot">
                  {has ? (
                    on ? (
                      <span className="pill">Running</span>
                    ) : (
                      <button type="button" className="btn btn-sm" disabled={!loggedIn || busy !== null} onClick={() => act(k.id, "equip")}>
                        {busy === k.id ? "…" : "Equip"}
                      </button>
                    )
                  ) : (
                    <>
                      <span className="temple-price">
                        <span className="coin" aria-hidden /> {k.price}
                      </span>
                      <button
                        type="button"
                        className="btn btn-sm btn-primary"
                        disabled={!loggedIn || busy !== null || coins < k.price}
                        onClick={() => act(k.id, "buy")}
                      >
                        {busy === k.id ? "…" : loggedIn ? "Unlock" : "Log in"}
                      </button>
                    </>
                  )}
                </div>
              </article>
            );
          })}
        </div>
      </div>
    </div>,
    document.body,
  );
}
