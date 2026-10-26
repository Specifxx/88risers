"use client";

import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { buySkin, equipSkin, submitScore } from "@/app/(site)/account/actions";
import { lionSays } from "@/lib/lion";
import { ABILITIES, ABILITIES3, ANIM, type Boss, DEFAULT_SKIN, LEVELS, MOVES, type MoveKind, POWERS, type PowerKind, SKINS, type Wallet, chainMove, moveOf, skinById } from "@/lib/pinrun";
import { drawAura, drawFx, newFx, stepFx } from "@/lib/pinrun-fx";
import { RADIO } from "@/lib/radio";

/** 88.5 Golden Hour (summer Afro house) plays while you run; the Arena switches to 88.8 Phonk. */
const GAME_STATION = RADIO.find((c) => c.id === "golden-hour") ?? RADIO[0];
const ARENA_STATION = RADIO.find((c) => c.id === "phonk") ?? GAME_STATION;
const stationFor = (level: number) => (level === 3 ? ARENA_STATION : GAME_STATION);

type Lv = 1 | 2 | 3;

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

type Plat = {
  x: number;
  w: number;
  y: number;
  rival: Rival | null;
  /** Level 2: platforms that bob up and down around baseY. */
  baseY: number;
  move: null | { amp: number; spd: number; ph: number };
  /** The Arena: spilled water, you skid. */
  wet?: boolean;
  /** Made to pump up and down by a Hydraulic Press (reverts after). */
  pumped?: boolean;
};
/** hp = grips still needed. In an Arena supermatch, `lost` counts the rounds the boss has won (first to 2). */
/** `finish`: the finishing grip on the chasing boss after you've drained their stamina. */
type BossFight = { b: Boss; hp: number; max: number; sm?: boolean; lost?: number; finish?: boolean };
/** The Arena: the Riser chasing you, and the move they're about to throw at the level. */
type Chase = {
  b: Boss;
  /** 0 = way back, 1 = they've caught you. */
  prox: number;
  /** Drained by pins; at 0 they're open to a finishing grip. */
  stamina: number;
  staggers: number;
  next: number;
  warn: number;
  coming: MoveKind | null;
  /** Fake-Out: the move shown in the warning (not the one coming). */
  shown: MoveKind | null;
  queue: MoveKind[];
  tilt: number;
  dark: number;
  drag: number;
  wind: number;
  pump: number;
  /** Ice Crystal (Cold Stare): frozen in place for a moment after each move. */
  chill: number;
  /** A finishing grip is waiting on a table ahead. */
  finisher: boolean;
};
const CHASE_MOVES: MoveKind[] = ["toproll", "hook", "hydraulic", "press", "side", "kings", "fake"];
/** What each signature move does to the level in a chase. */
const CHASE_TIP: Record<string, string> = {
  toproll: "THE ARENA TILTS",
  hook: "DRAGS YOU BACK",
  hydraulic: "TABLES PUMP UP AND DOWN",
  press: "THE TABLES SLAM DOWN",
  side: "HEAVY AIR: SHORTER JUMPS",
  kings: "LIGHTS OUT",
  fake: "OR IS IT?",
};
const MOVE_SECS = 4.5;
/** `two`: a double grip (lock both hands). */
type Rival = { x: number; state: "idle" | "pinned" | "gone"; vy: number; y: number; vx: number; spin: number; boss?: BossFight; two?: boolean };
type Cloud = { x: number; y: number; got: boolean };
/** Something the Arena crowd threw: a water bottle (costs a heart) or a chalk bag (blinds you). */
type Throw = { x: number; y: number; vx: number; vy: number; kind: "bottle" | "chalk"; spin: number; done: boolean };
type Power = { x: number; y: number; kind: PowerKind; got: boolean };
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
  duel: null | {
    rival: Rival;
    plat: Plat;
    t: number;
    zone: number;
    width: number;
    speed: number;
    result: null | "pin" | "miss" | "hit";
    rt: number;
    /** Needle phase, direction and position (0-1). */
    ph: number;
    dir: number;
    pos: number;
    /** The boss's signature move this round, and its starting zone/width. */
    move: MoveKind | null;
    z0: number;
    w0: number;
    /** Hook: seconds until the needle snaps back. */
    flip: number;
    /** Fake-Out: the zone already jumped this round. */
    used: boolean;
    /** Shake on the boss art when a move kicks in. */
    fx: number;
    /** Double grip: where the first hand locked (null until it has). */
    two: boolean;
    lockA: number | null;
  };
  over: boolean;
  level: Lv;
  skin: string;
  maxHearts: number;
  shield: boolean;
  /** Seconds left on timed power-ups. */
  pw: { magnet: number; x2: number };
  /** Moonlight: seconds until a broken shield comes back. */
  shieldBack: number;
  /** Ice Crystal: the one free slipped grip has been used. */
  frostUsed: boolean;
  powers: Power[];
  nextBoss: number;
  bossIdx: number;
  waveUsed: boolean;
  /** A message pinned to the top of the screen (ability, unlocks). */
  banner: null | { t: string; sub: string; life: number; c: string };
  runFrame: number;
  /** Landing squash timer. */
  land: number;
  /** The Arena: crowd hype (0-100); full sets off Beast Mode for `beast` seconds. */
  hype: number;
  beast: number;
  /** Chalk in your eyes (seconds), chalk clouds to dodge, the ref's whistle freeze. */
  chalk: number;
  clouds: Cloud[];
  whistle: number;
  frozen: number;
  /** The crowd jumping (decays). */
  cheer: number;
  /** Last wet table we skidded on (so the "SLIPPERY" pop shows once). */
  wetSeen: Plat | null;
  /** Beast Mode length this time (Wildfire makes it longer). */
  beastMax: number;
  throws: Throw[];
  throwT: number;
  /** Full hype waits for you: hold (or B) to unleash Beast Mode. */
  beastReady: boolean;
  holdT: number;
  /** The Arena: the Riser chasing you. */
  chase: Chase | null;
}

const rand = (a: number, b: number) => a + Math.random() * (b - a);

function newWorld(level: Lv = 1, skin = DEFAULT_SKIN): World {
  const first: Plat = { x: -200, w: 900, y: 400, rival: null, baseY: 400, move: null };
  const adv = level >= 2;
  const hearts = adv && skin === "eclipse" ? 4 : 3;
  return {
    level,
    skin,
    maxHearts: hearts,
    shield: adv && skin === "moon",
    pw: { magnet: 0, x2: 0 },
    shieldBack: 0,
    frostUsed: false,
    powers: [],
    nextBoss: level === 3 ? 3200 : 6000,
    bossIdx: Math.floor(Math.random() * 1000),
    waveUsed: false,
    banner: null,
    t: 0,
    dist: 0,
    speed: level === 3 ? 390 : level === 2 ? 365 : 330,
    boost: 0,
    y: first.y - R,
    vy: 0,
    ground: first,
    coyote: 0,
    jumps: 0,
    holding: false,
    hearts,
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
    hype: 0,
    beast: 0,
    chalk: 0,
    clouds: [],
    whistle: rand(14, 22),
    frozen: 0,
    cheer: 0,
    wetSeen: null,
    beastMax: 6,
    throws: [],
    throwT: 4,
    beastReady: false,
    holdT: 0,
    chase: null,
  };
}

function extend(w: World, bosses: Boss[] = []) {
  let last = w.plats[w.plats.length - 1];
  while (last.x + last.w < w.dist + W * 2) {
    const level = Math.min(1, w.dist / 30000);
    const n = w.plats.length;
    let p: Plat;
    let gap: number;
    if (w.level === 1) {
      // Tuned for the lion's size: shorter tables, bigger steps and gaps than the original circle needed.
      gap = rand(100, 165 + level * 130) * (w.speed / 330);
      const width = rand(175, 340) - level * 70;
      const y = Math.max(235, Math.min(460, last.y + rand(-140, 125)));
      const x = last.x + last.w + gap;
      const rivalChance = n < 4 ? 0 : 0.32 + level * 0.25;
      p = { x, w: width, y, rival: null, baseY: y, move: null };
      if (Math.random() < rivalChance && width > 200) p.rival = { x: x + width * rand(0.45, 0.7), state: "idle", vy: 0, y: 0, vx: 0, spin: 0 };
    } else if (w.level === 3) {
      // The Arena: stage tables (some wet), floating rigs and double-grip rivals, with a Riser on your tail.
      const stair = n > 3 && Math.random() < 0.15;
      gap = (stair ? rand(50, 80) : rand(115, 185 + level * 130)) * (w.speed / 390);
      const width = stair ? rand(140, 190) : rand(165, 300) - level * 55;
      const step = stair ? (Math.random() < 0.5 ? -1 : 1) * rand(95, 130) : rand(-150, 135);
      const y = Math.max(225, Math.min(450, last.baseY + step));
      const x = last.x + last.w + gap;
      const mover = !stair && n > 3 && Math.random() < 0.3 + level * 0.12;
      const amp = mover ? rand(35, 65) : 0;
      const baseY = Math.max(215 + amp, Math.min(455 - amp, y));
      p = { x, w: width, y: baseY, rival: null, baseY, move: mover ? { amp, spd: rand(1.3, 2.3), ph: rand(0, Math.PI * 2) } : null };
      if (!mover && n > 3 && Math.random() < 0.22) p.wet = true;
      if (!mover && n > 3 && width > 185 && Math.random() < 0.34 + level * 0.25)
        p.rival = { x: x + width * rand(0.45, 0.7), state: "idle", vy: 0, y: 0, vx: 0, spin: 0, two: n > 5 && Math.random() < 0.4 };
    } else {
      // Crimson Peak: narrower ledges, steep staircases and platforms that bob up and down.
      const boss = bosses.length > 0 && w.dist + W * 2 > w.nextBoss && n > 3;
      const stair = !boss && n > 3 && Math.random() < 0.2;
      gap = (stair ? rand(45, 75) : rand(110, 180 + level * 130)) * (w.speed / 365);
      const width = boss ? rand(360, 420) : stair ? rand(140, 190) : rand(160, 310) - level * 60;
      const step = stair ? (Math.random() < 0.5 ? -1 : 1) * rand(95, 130) : rand(-150, 135);
      const y = Math.max(225, Math.min(465, last.baseY + step));
      const x = last.x + last.w + gap;
      const mover = !boss && !stair && n > 3 && Math.random() < 0.36 + level * 0.12;
      const amp = mover ? rand(35, 65) : 0;
      const baseY = Math.max(215 + amp, Math.min(470 - amp, y));
      p = { x, w: width, y: baseY, rival: null, baseY, move: mover ? { amp, spd: rand(1.3, 2.3), ph: rand(0, Math.PI * 2) } : null };
      if (boss) {
        const b = bosses[w.bossIdx++ % bosses.length];
        p.rival = { x: x + width * 0.62, state: "idle", vy: 0, y: 0, vx: 0, spin: 0, boss: { b, hp: 3, max: 3 } };
        w.nextBoss = x + 9000;
      } else if (!mover && n > 3 && width > 190 && Math.random() < 0.3 + level * 0.25) {
        p.rival = { x: x + width * rand(0.45, 0.7), state: "idle", vy: 0, y: 0, vx: 0, spin: 0 };
      }
      if (n > 3 && !boss && Math.random() < 0.16) {
        const kinds: PowerKind[] = ["shield", "magnet", "x2"];
        w.powers.push({ x: x + width * 0.4, y: baseY - 105 - (p.move?.amp ?? 0), kind: kinds[Math.floor(Math.random() * kinds.length)], got: false });
      }
    }
    const { x, w: width, y } = p;
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
  w.powers = w.powers.filter((c) => c.x > w.dist - 400);
  w.clouds = w.clouds.filter((c) => c.x > w.dist - 400);
}

export function PinRun({
  loggedIn,
  best: initialBest,
  best2: initialBest2 = null,
  best3: initialBest3 = null,
  wallet: initialWallet,
  bosses = [],
}: {
  loggedIn: boolean;
  best: number | null;
  best2?: number | null;
  best3?: number | null;
  wallet: Wallet | null;
  bosses?: Boss[];
}) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const world = useRef<World>(newWorld());
  const [phase, setPhase] = useState<"title" | "play" | "over">("title");
  const phaseRef = useRef(phase);
  const [final, setFinal] = useState<{ score: number; pins: number; coins: number; level: Lv }>({ score: 0, pins: 0, coins: 0, level: 1 });
  const [best, setBest] = useState<number | null>(initialBest);
  const [best2, setBest2] = useState<number | null>(initialBest2);
  const [best3, setBest3] = useState<number | null>(initialBest3);
  const bestOf = (l: Lv) => (l === 3 ? best3 : l === 2 ? best2 : best);
  const setBestOf = (l: Lv) => (l === 3 ? setBest3 : l === 2 ? setBest2 : setBest);
  const [level, setLevel] = useState<Lv>(1);
  const levelRef = useRef<Lv>(1);
  levelRef.current = level;
  const [wallet, setWallet] = useState<Wallet | null>(initialWallet);
  const bossImgs = useRef<Record<number, HTMLImageElement>>({});
  /** The on-screen Beast button (Level 3): hype filled (0-10) / ready / active. */
  const [beastUi, setBeastUi] = useState<{ on: boolean; fill: number; ready: boolean; active: boolean }>({ on: false, fill: 0, ready: false, active: false });
  const beastUiKey = useRef("");
  const bossesRef = useRef(bosses);
  bossesRef.current = bosses;
  const [saveMsg, setSaveMsg] = useState<string | null>(null);
  const [muted, setMuted] = useState(false);
  const mutedRef = useRef(false);
  const audio = useRef<AudioContext | null>(null);
  const overAt = useRef(0);
  const imgs = useRef<{ skin?: HTMLImageElement; cloud?: HTMLImageElement; ring?: HTMLImageElement; l2bg?: HTMLImageElement; l3bg?: HTMLImageElement }>({});
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

  // ── Radio: 88.5 Golden Hour, started by the first Start tap (browsers need a tap to play audio).
  const radio = useRef<HTMLAudioElement | null>(null);
  const radioTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [onAir, setOnAir] = useState(false);
  const onAirRef = useRef(false);
  onAirRef.current = onAir;
  const station = useRef(GAME_STATION);
  const tuneRadio = (i = 0) => {
    const stations = station.current.stations;
    if (i >= stations.length) return;
    radio.current ??= new Audio();
    const a = radio.current;
    a.volume = 0.5;
    if (radioTimer.current) clearTimeout(radioTimer.current);
    // a station that hasn't started within 10s is skipped
    radioTimer.current = setTimeout(() => a.paused && tuneRadio(i + 1), 10000);
    a.onplaying = () => {
      if (radioTimer.current) clearTimeout(radioTimer.current);
      setOnAir(true);
    };
    a.onerror = () => tuneRadio(i + 1);
    a.src = stations[i].url;
    a.play().catch(() => {});
  };
  const startRadio = () => {
    if (mutedRef.current) return;
    const a = radio.current;
    if (a && !a.paused) return;
    if (a?.src) a.play().catch(() => tuneRadio(0));
    else tuneRadio(0);
  };
  const stopRadio = () => {
    radio.current?.pause();
    setOnAir(false);
  };
  useEffect(
    () => () => {
      if (radioTimer.current) clearTimeout(radioTimer.current);
      radio.current?.pause();
      if (radio.current) radio.current.src = "";
    },
    [],
  );

  const start = () => {
    const want = stationFor(levelRef.current);
    if (want !== station.current) {
      // switching channel (the Arena plays Phonk)
      station.current = want;
      setOnAir(false);
      if (!mutedRef.current) tuneRadio(0);
    } else startRadio();
    world.current = newWorld(levelRef.current, skinRef.current);
    if (levelRef.current === 3) {
      // a random Riser chases you each run
      const pool = bossesRef.current;
      const b = pool[Math.floor(Math.random() * pool.length)];
      if (b)
        world.current.chase = { b, prox: 0.25, stamina: 100, staggers: 0, next: 5, warn: 0, coming: null, shown: null, queue: [], tilt: 0, dark: 0, drag: 0, wind: 0, pump: 0, chill: 0, finisher: false };
    }
    extend(world.current, bossesRef.current);
    if (levelRef.current >= 2) {
      const ab = (levelRef.current === 3 ? ABILITIES3 : ABILITIES)[skinRef.current];
      if (ab) world.current.banner = { t: `${(skinById(skinRef.current)?.name ?? "").toUpperCase()} · ${ab.name.toUpperCase()}`, sub: ab.text, life: 3, c: "#f2e1b6" };
    }
    setSaveMsg(null);
    setPhase("play");
  };

  /** The Arena: spend full hype on Beast Mode (in a match it's a huge push). */
  const unleash = () => {
    const w = world.current;
    if (w.level !== 3 || !w.beastReady || phaseRef.current !== "play" || w.over) return;
    w.beastReady = false;
    w.hype = 0;
    w.beastMax = w.skin === "flame" ? 9 : 6; // Wildfire
    w.beast = w.beastMax;
    w.cheer = 2;
          if (w.skin === "thunder") {
            // Thunderclap: every ordinary rival on screen is pinned
            let k = 0;
            for (const q of w.plats) {
              const r = q.rival;
              if (!r || r.boss || r.state !== "idle" || r.x < w.dist || r.x > w.dist + W) continue;
              r.state = "pinned";
              r.vx = 300;
              r.vy = -900;
              k++;
              for (let i = 0; i < 14; i++) w.parts.push({ x: r.x, y: q.y - rand(0, 200), vx: rand(-60, 60), vy: rand(-80, 80), life: 0.5, c: i % 2 ? "#fff6c8" : "#f2c14e", s: rand(2, 4) });
            }
            if (k) {
              w.pins += k;
              w.score += 150 * k;
              if (w.chase) {
                w.chase.prox = Math.max(0, w.chase.prox - 0.1 * k);
                if (!w.chase.finisher) w.chase.stamina = Math.max(0, w.chase.stamina - 10 * k);
              }
              w.pops.push({ x: w.dist + PX + 120, y: 190, t: `THUNDERCLAP x${k}! +${150 * k}`, life: 1.4, c: "#f2c14e" });
            }
            w.shake = 0.4;
            if (w.chase) {
              w.chase.prox = Math.max(0, w.chase.prox - 0.3);
            }
          }
    w.banner = { t: "BEAST MODE! 2X POINTS", sub: "Rivals get pinned on contact. Bottles smash. Coins come to you.", life: 2.2, c: "#ff4a4f" };
    w.shake = Math.max(w.shake, 0.4);
    beep(220, 0.3, "sawtooth", 0.06);
    setTimeout(() => beep(440, 0.3, "sawtooth", 0.06), 120);
  };

  // One input does everything: start, jump, double jump, grip, mash.
  const press = () => {
    const w = world.current;
    if (phaseRef.current === "title") return start();
    if (phaseRef.current === "over") {
      if (performance.now() - overAt.current > 900) start();
      return;
    }
    w.holdT = 0;
    if (w.duel) {
      if (w.duel.result) return;
      const hit = Math.abs(w.duel.pos - w.duel.zone) < w.duel.width / 2;
      const boss = w.duel.rival.boss;
      if (w.duel.two && w.duel.lockA === null && hit) {
        // first hand locked in; now the second needle, a touch faster
        const d = w.duel;
        d.lockA = d.pos;
        d.t = 0;
        d.ph = rand(0, Math.PI * 2);
        d.speed *= 1.15;
        beep(760, 0.08, "square", 0.05);
        return;
      }
      if (hit && boss) {
        boss.hp--;
        w.duel.result = boss.hp > 0 ? "hit" : "pin";
        beep(boss.hp > 0 ? 760 : 880, 0.1, "square", 0.06);
      } else w.duel.result = hit ? "pin" : "miss";
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
    } else if (w.jumps < (w.level >= 2 && w.skin === "thunder" ? 3 : 2)) {
      w.vy = -JUMP2;
      w.jumps++;
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
    const l2bg = new Image();
    l2bg.src = "/pinrun/l2-bg.webp";
    const l3bg = new Image();
    l3bg.src = "/pinrun/l3-bg.webp";
    imgs.current = { ...imgs.current, cloud, ring, l2bg, l3bg };

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
      if (e.type === "keydown" && (e.code === "KeyB" || e.code === "ShiftLeft" || e.code === "ShiftRight")) unleash();
    };
    window.addEventListener("keydown", key);
    window.addEventListener("keyup", key);
    return () => {
      window.removeEventListener("keydown", key);
      window.removeEventListener("keyup", key);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Boss portraits (real Risers).
  useEffect(() => {
    for (const b of bosses) {
      const src = b.art ?? b.photo;
      if (!src || bossImgs.current[b.id]) continue;
      const img = new Image();
      img.src = src;
      bossImgs.current[b.id] = img;
    }
  }, [bosses]);

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
      setFinal({ score, pins: w.pins, coins: w.coins, level: w.level });
      setPhase("over");
      overAt.current = performance.now();
      beep(160, 0.5, "sawtooth", 0.06);
      if (loggedIn) {
        const lv = w.level;
        submitScore(score, w.coins, lv)
          .then((r) => {
            if (r.best !== null) setBestOf(lv)(r.best);
            if (r.wallet) setWallet(r.wallet);
            const banked = r.saved && r.wallet ? `+${r.saved} Temple coins banked (${r.wallet.coins.toLocaleString("en-AU")} total).` : "";
            setSaveMsg([r.message, banked].filter(Boolean).join(" "));
            if (r.coins) lionSays("cheer", `+${r.coins} coins for today's run!`);
          })
          .catch(() => setSaveMsg("Couldn't save that run. Check your connection and play again."));
      } else setBestOf(w.level)((b) => Math.max(b ?? 0, score));
    };

    /** Lose a heart, unless a shield soaks it up. Returns true if the run is over. */
    const hurt = (w: World, label: string) => {
      w.combo = 1;
      w.shake = 0.3;
      if (w.shield) {
        w.shield = false;
        if (w.level >= 2 && w.skin === "moon") w.shieldBack = 30;
        w.pops.push({ x: w.dist + PX, y: w.y - 80, t: "SHIELD!", life: 1, c: "#7fc8ff" });
        beep(600, 0.15, "triangle", 0.06);
        return false;
      }
      w.hearts--;
      if (w.level === 3) w.hype = Math.max(0, w.hype - 25);
      if (w.chase) w.chase.prox = Math.max(w.chase.prox, Math.min(0.9, w.chase.prox + 0.06));
      w.pops.push({ x: w.dist + PX, y: w.y - 70, t: label, life: 1, c: "#ff4a4f" });
      beep(200, 0.25, "sawtooth", 0.06);
      return w.hearts <= 0;
    };

    /** Adds crowd hype. */
    const addHype = (w: World, n: number) => {
      if (w.level !== 3 || w.beast > 0) return;
      w.hype = Math.min(100, w.hype + n);
    };

    const newRound = (w: World, boss: boolean) => {
      const d = w.duel!;
      const diff = Math.min(1, w.dist / 30000);
      const l2 = w.level >= 2;
      let width = boss ? 0.2 - diff * 0.05 - (d.rival.boss!.max - d.rival.boss!.hp) * 0.02 : 0.24 - diff * 0.12;
      let speed = boss ? 5 + diff * 3 + (d.rival.boss!.max - d.rival.boss!.hp) * 0.7 : 4.2 + diff * 3.5;
      if (l2 && w.skin === "stone") width *= 1.15;
      if (l2 && w.skin === "crystal") speed *= 0.7;
      const bf = d.rival.boss;
      const id = bf?.b.id ?? 0;
      const move = bf ? (moveOf(id) === "chain" ? chainMove(bf.max - bf.hp) : moveOf(id)) : null;
      if (move === "press") width *= 1.3; // starts wide, then gets crushed
      if (move === "toproll" || move === "kings") width *= 1.1;
      if (move === "hydraulic") width *= 1.25;
      if (move === "hook") width *= 1.15;
      if (bf?.sm) speed *= 1.1; // supermatch: everything a notch faster
      d.two = !bf && !!d.rival.two && !(w.level === 3 && w.skin === "moon"); // One Hand
      d.lockA = null;
      if (d.two) width *= 1.1;
      d.t = 0;
      d.zone = move === "side" ? rand(0.55, 0.8) : rand(0.25, 0.75);
      d.width = width;
      d.speed = speed;
      d.result = null;
      d.rt = 0;
      d.ph = 0;
      d.dir = 1;
      d.pos = 0.5;
      d.move = move;
      d.z0 = d.zone;
      d.w0 = width;
      d.flip = rand(0.8, 1.3);
      d.used = false;
      d.fx = move ? 0.4 : 0;
      if (move) beep(160, 0.25, "sawtooth", 0.05);
    };

    /** Moves the needle and applies the boss's signature move. */
    const stepNeedle = (d: NonNullable<World["duel"]>, dt: number) => {
      d.fx = Math.max(0, d.fx - dt);
      let mul = 1;
      if (d.move === "hook") {
        d.flip -= dt;
        if (d.flip <= 0) {
          d.dir *= -1;
          d.flip = rand(0.75, 1.3); // readable: a snap every second or so
          d.fx = 0.2;
          beep(240, 0.06, "square", 0.04);
        }
      } else if (d.move === "hydraulic") {
        // pumps slow, then surges (averages out to normal speed, so it's readable)
        const c = d.t % 1.0;
        mul = c < 0.75 ? 0.8 : 1.45;
        if (c >= 0.75 && c - dt < 0.75) d.fx = 0.25;
      }
      d.ph += dt * d.speed * mul * d.dir;
      const raw = (Math.sin(d.ph) + 1) / 2;
      d.pos = d.move === "side" ? raw ** 2.2 : raw;
      if (d.move === "toproll") {
        const half = d.width / 2 + 0.02;
        d.zone = Math.min(1 - half, Math.max(half, d.z0 + Math.sin(d.t * 1.7) * 0.22));
      } else if (d.move === "press") {
        d.width = d.w0 * Math.max(0.36, 1 - d.t * 0.32);
      } else if (d.move === "fake" && !d.used && d.t > 0.35 && Math.abs(d.pos - d.zone) < d.width / 2 + 0.1) {
        d.used = true;
        d.zone = d.zone < 0.5 ? rand(0.62, 0.8) : rand(0.2, 0.38);
        d.fx = 0.3;
        beep(300, 0.08, "square", 0.04);
      }
    };

    /** Pushes the chasing boss back (and drains their stamina): pins, coins, Beast Mode. */
    const pushBoss = (w: World, back: number, drain: number) => {
      const c = w.chase;
      if (!c) return;
      // they never drop fully out of sight (a stagger is the only thing that sends them all the way back)
      c.prox = Math.max(0.15, c.prox - back);
      if (!c.finisher) c.stamina = Math.max(0, c.stamina - drain);
    };

    /** A signature move lands on the level. */
    const fireMove = (w: World, c: Chase, kind: MoveKind) => {
      const name = c.b.name.split(" ")[0].toUpperCase();
      const onScreen = (p: Plat) => p.x < w.dist + W + 300 && p.x + p.w > w.dist - 50;
      if (kind === "press") {
        for (const p of w.plats) {
          if (!onScreen(p)) continue;
          if (w.skin === "stone" && p === w.ground) continue; // Rooted
          const amp = p.move?.amp ?? 0;
          p.baseY = Math.min(470 - amp, p.baseY + 70);
          if (!p.move) p.y = p.baseY;
          for (let i = 0; i < 6; i++) w.parts.push({ x: p.x + rand(0, p.w), y: p.y, vx: rand(-90, 90), vy: rand(-200, -60), life: 0.4, c: "#efe7d6", s: 3 });
        }
        w.shake = 0.6;
      } else if (kind === "toproll") c.tilt = MOVE_SECS;
      else if (kind === "hook") {
        if (w.skin === "stone") w.pops.push({ x: w.dist + PX, y: w.y - 90, t: "ROOTED!", life: 1, c: "#d5b67a" });
        else {
          c.drag = 1.3;
          c.prox = Math.min(0.95, c.prox + 0.12);
        }
      } else if (kind === "hydraulic") {
        c.pump = MOVE_SECS;
        for (const p of w.plats) {
          if (!onScreen(p) || p.move) continue;
          p.move = { amp: 45, spd: 3.2, ph: rand(0, Math.PI * 2) };
          p.pumped = true;
        }
      } else if (kind === "side") c.wind = MOVE_SECS;
      else if (kind === "kings") c.dark = MOVE_SECS;
      w.pops.push({ x: w.dist + PX + 460, y: 200, t: `${name}'S ${MOVES[kind].name.toUpperCase()}!`, life: 1.2, c: MOVES[kind].color });
      beep(110, 0.35, "sawtooth", 0.06);
      if (w.skin === "crystal") {
        // Cold Stare: they freeze after showing their hand
        c.chill = 2.5;
        w.pops.push({ x: w.dist + PX, y: w.y - 110, t: "COLD STARE", life: 1, c: "#9fe0ff" });
      }
    };

    /** The Arena chase, each frame. Returns true if the run is over. */
    const stepChase = (w: World, dt: number) => {
      const c = w.chase!;
      for (const k of ["tilt", "dark", "drag", "wind", "chill"] as const) c[k] = Math.max(0, c[k] - dt);
      if (c.pump > 0 && (c.pump -= dt) <= 0) {
        for (const p of w.plats)
          if (p.pumped) {
            p.pumped = false;
            p.move = null;
            p.y = p.baseY;
          }
      }
      // they close in; Beast Mode drives them back
      // Clean running out-paces them (landings, coins, pins all push back); falls, slips and their
      // moves are what let them catch you. They get a little quicker every time you stagger them.
      const rate = (0.024 + c.staggers * 0.008 + Math.min(0.015, w.dist / 500000)) * (w.skin === "eclipse" ? 0.75 : 1);
      if (w.beast > 0) pushBoss(w, 0.3 * dt, 9 * dt);
      else if (c.chill <= 0) c.prox += rate * dt * (c.drag > 0 ? 3 : 1);
      if (c.prox >= 1) {
        c.prox = 0.4;
        w.shake = 0.5;
        if (w.invuln === 0) {
          w.invuln = 1.2;
          if (hurt(w, "CAUGHT!")) return true;
        }
      }
      // their signature moves, telegraphed
      if (c.warn > 0) {
        if ((c.warn -= dt) <= 0) {
          const kind = c.coming!;
          if (kind === "fake") {
            // Fake-Out: nothing... then the real thing, fast
            w.pops.push({ x: w.dist + PX + 460, y: 200, t: "FAKE-OUT!", life: 1, c: MOVES.fake.color });
            const real = CHASE_MOVES.filter((k) => k !== "fake")[Math.floor(Math.random() * 6)];
            c.coming = real;
            c.shown = real;
            c.warn = 0.5;
          } else {
            fireMove(w, c, kind);
            if (c.queue.length) {
              c.coming = c.queue.shift()!;
              c.shown = c.coming;
              c.warn = 0.9;
            } else {
              c.coming = null;
              c.next = Math.max(2.8, rand(5, 8) - c.staggers * 0.6);
            }
          }
        }
      } else if ((c.next -= dt) <= 0) {
        const mv = moveOf(c.b.id);
        let kind: MoveKind = mv;
        if (mv === "chain") {
          // Champion's Chain: two moves back to back
          const pick = () => CHASE_MOVES.filter((k) => k !== "fake")[Math.floor(Math.random() * 6)];
          kind = pick();
          c.queue = [pick()];
        }
        c.coming = kind;
        c.shown = kind === "fake" ? CHASE_MOVES.filter((k) => k !== "fake")[Math.floor(Math.random() * 6)] : kind;
        c.warn = 1.1;
        beep(520, 0.1, "square", 0.04);
      }
      // missed the finishing table (fell past it)? they'll set up another
      if (c.finisher && !w.plats.some((p) => p.rival?.boss?.finish && p.rival.state === "idle" && p.rival.x > w.dist)) c.finisher = false;
      // stamina gone: a finishing grip on a table just ahead
      if (c.stamina <= 0 && !c.finisher) {
        const px = w.dist + PX;
        const t = w.plats.find((p) => p.x > px + 260 && p.w > 170 && !p.move && !p.rival);
        if (t) {
          c.finisher = true;
          t.wet = false;
          t.rival = { x: t.x + t.w * 0.55, state: "idle", vy: 0, y: 0, vx: 0, spin: 0, boss: { b: c.b, hp: w.skin === "moon" ? 2 : 3, max: w.skin === "moon" ? 2 : 3, finish: true } };
          w.banner = { t: `${c.b.name.split(" ")[0].toUpperCase()} IS GASSED!`, sub: "Reach the table ahead and finish the grip.", life: 2.2, c: "#f2c14e" };
          beep(880, 0.15, "square", 0.05);
        }
      }
      return false;
    };

    const step = (dt: number) => {
      const w = world.current;
      w.t += dt;
      if (w.holding) w.holdT += dt;
      if (w.level === 3 && w.beastReady && w.holding && w.holdT >= 0.45) unleash();
      const l2 = w.level >= 2; // lion abilities are on from Level 2
      const l3 = w.level === 3;
      if (w.duel) {
        const d = w.duel;
        const boss = d.rival.boss;
        d.t += dt;
        if (!d.result) stepNeedle(d, dt);
        if (!d.result && d.t > (boss ? 3 : d.two ? 2.8 : 2.4)) {
          d.result = "miss";
          d.rt = 0;
        }
        if (d.result) {
          d.rt += dt;
          if (d.rt > 0.55) {
            if (d.result === "hit") {
              newRound(w, true);
              return;
            }
            if (d.result === "pin") {
              w.pins++;
              const blaze = l2 && w.skin === "flame";
              const sm = !!boss?.sm;
              const gain = Math.round((sm ? 3000 : boss ? 1500 : 100 * w.combo * (d.two ? 2 : 1)) * (blaze ? 1.5 : 1));
              w.score += gain;
              w.pops.push({
                x: w.dist + PX,
                y: w.y - 70,
                t: sm ? `ARENA CHAMPION! +${gain}` : boss ? `BOSS PINNED! +${gain}` : `${d.two ? "DOUBLE PIN" : "PIN"}! +${gain}`,
                life: boss ? 1.8 : 1.1,
                c: "#f2e1b6",
              });
              if (l3) {
                addHype(w, boss ? 40 : d.two ? 26 : 18);
                w.cheer = boss ? 2 : 1;
              }
              if (boss?.finish && w.chase) {
                // the finishing grip: a big score bonus, and they come back angrier
                const c = w.chase;
                const hitDmg = Math.round(1500 * (c.staggers + 1) * (w.skin === "eclipse" ? 1.5 : 1)); // Blood Moon: bigger staggers
                w.score += hitDmg;
                c.staggers++;
                c.stamina = 100;
                c.prox = 0;
                c.finisher = false;
                w.pops.push({ x: w.dist + PX + 60, y: w.y - 130, t: `STAGGER +${hitDmg.toLocaleString("en-AU")}`, life: 1.8, c: "#ff6a4f" });
                w.banner = { t: "STAGGERED!", sub: `${c.b.name} is back up, and angrier. Keep running.`, life: 2.4, c: "#f2c14e" };
              } else if (!boss) pushBoss(w, d.two ? 0.24 : 0.16, d.two ? 20 : 14);
              if (sm) w.banner = { t: "ARENA CHAMPION!", sub: `You beat ${boss!.b.name} in the supermatch.`, life: 2.6, c: "#f2c14e" };
              if (boss) {
                // a shower of coins (each worth score, like any coin)
                const k = sm ? 25 : 12;
                w.coins += k;
                w.score += 10 * k;
                w.pops.push({ x: w.dist + PX + 40, y: w.y - 110, t: `+${k} coins`, life: 1.6, c: "#d5b67a" });
                if (l2 && w.skin === "eclipse" && w.hearts < w.maxHearts) {
                  w.hearts++;
                  w.pops.push({ x: w.dist + PX - 40, y: w.y - 140, t: "+1 HEART", life: 1.6, c: "#ff6a6f" });
                }
              }
              w.combo = Math.min(8, w.combo + 1);
              d.rival.state = "pinned";
              d.rival.vx = 520;
              d.rival.vy = -700;
              w.vy = -1000;
              w.ground = null;
              w.jumps = 1;
              w.boost = blaze ? 2.4 : 1.6;
              w.shake = boss ? 0.5 : 0.35;
              beep(880, 0.12, "square", 0.06);
              setTimeout(() => beep(1320, 0.16, "square", 0.06), 90);
              if (boss) setTimeout(() => beep(1760, 0.2, "square", 0.06), 200);
              for (let i = 0; i < (boss ? 60 : 26); i++)
                w.parts.push({ x: d.rival.x, y: d.plat.y - 30, vx: rand(-320, 320), vy: rand(-420, 60), life: rand(0.4, 0.9), c: i % 3 ? "#d5b67a" : "#ff4a4f", s: rand(2, 5) });
              w.duel = null;
            } else {
              let dead = false;
              if (!boss && l2 && w.skin === "crystal" && !w.frostUsed) {
                // Frost Grip: the first slipped grip on an ordinary rival is free
                w.frostUsed = true;
                w.combo = 1;
                w.pops.push({ x: w.dist + PX, y: w.y - 80, t: "FROST GRIP!", life: 1, c: "#9fe0ff" });
                beep(600, 0.15, "triangle", 0.06);
              } else dead = hurt(w, boss ? "SLAMMED!" : "SLIPPED!");
              if (dead) return endGame();
              if (boss?.sm && (boss.lost = (boss.lost ?? 0) + 1) >= 2) {
                // lost the supermatch: the boss takes it 2 rounds to whatever, and you run on
                w.banner = { t: "SUPERMATCH LOST", sub: `${boss.b.name} takes it. Run it back next time.`, life: 2.4, c: "#ff4a4f" };
                w.invuln = 1.4;
                d.rival.state = "gone";
                w.vy = -420;
                w.ground = null;
                w.duel = null;
                return;
              }
              if (boss) {
                // a boss doesn't let go: next round
                newRound(w, true);
                w.invuln = 0;
                return;
              }
              w.invuln = 1.2;
              d.rival.state = "gone";
              w.vy = -420;
              w.ground = null;
              w.duel = null;
            }
          }
        }
        return;
      }

      // power-up timers
      w.pw.magnet = Math.max(0, w.pw.magnet - dt);
      w.pw.x2 = Math.max(0, w.pw.x2 - dt);
      if (w.shieldBack > 0 && (w.shieldBack -= dt) <= 0) {
        w.shieldBack = 0;
        w.shield = true;
        w.pops.push({ x: w.dist + PX, y: w.y - 90, t: "MOON SHIELD", life: 1.1, c: "#b994ff" });
      }

      // the Arena: Beast Mode, chalk, the ref's whistle, the crowd
      if (l3) {
        w.beast = Math.max(0, w.beast - dt);
        w.chalk = Math.max(0, w.chalk - dt);
        w.frozen = Math.max(0, w.frozen - dt);
        w.cheer = Math.max(0, w.cheer - dt);
        if ((w.whistle -= dt) <= 0) {
          w.whistle = rand(14, 24);
          w.frozen = 1.8;
          w.pops.push({ x: w.dist + PX + 160, y: 150, t: "WHISTLE! FREEZE", life: 1.4, c: "#efe7d6" });
          beep(2600, 0.12, "sine", 0.05);
          setTimeout(() => beep(2600, 0.25, "sine", 0.05), 160);
        }
        if (w.hype >= 100 && w.beast === 0 && !w.beastReady) {
          // full hype waits for the player to unleash it
          w.beastReady = true;
          w.banner = { t: "HYPE FULL!", sub: "Tap BEAST (or hold the screen) to unleash Beast Mode.", life: 2.2, c: "#f2c14e" };
          beep(660, 0.12, "square", 0.05);
          setTimeout(() => beep(990, 0.14, "square", 0.05), 100);
        }
        // the crowd throws things onto the run
        if ((w.throwT -= dt) <= 0) {
          w.throwT = rand(2.4, 4.2);
          w.throws.push({ x: w.dist + PX + rand(420, 700), y: H + 10, vx: -rand(40, 140), vy: -rand(780, 940), kind: Math.random() < 0.35 ? "chalk" : "bottle", spin: 0, done: false });
          beep(320, 0.12, "triangle", 0.03);
        }
        const tpx = w.dist + PX;
        for (const t of w.throws) {
          t.vy += 1300 * dt;
          t.x += t.vx * dt;
          t.y += t.vy * dt;
          t.spin += dt * 9;
          if (t.done || Math.hypot(t.x - tpx, t.y - (w.y - 20)) > 36) continue;
          t.done = true;
          if (w.beast > 0) {
            w.pops.push({ x: tpx, y: w.y - 90, t: "SMASH!", life: 0.8, c: "#ff6a4f" });
            for (let i = 0; i < 10; i++) w.parts.push({ x: t.x, y: t.y, vx: rand(-250, 250), vy: rand(-250, 50), life: 0.4, c: t.kind === "bottle" ? "#9fe0c8" : "#ffffff", s: 3 });
          } else if (t.kind === "chalk") {
            if (w.skin === "sakura") {
              w.pops.push({ x: tpx, y: w.y - 90, t: "PETAL VEIL", life: 1, c: "#f3c4d2" });
            } else {
              w.chalk = 2.2;
              w.pops.push({ x: tpx, y: w.y - 90, t: "CHALK!", life: 1, c: "#ffffff" });
              beep(150, 0.2, "triangle", 0.05);
            }
          } else if (w.invuln === 0) {
            if (hurt(w, "BOTTLED!")) return endGame();
            w.invuln = 1;
          }
        }
        w.throws = w.throws.filter((t) => !t.done && !(t.vy > 0 && t.y > H + 60));
      }
      if (w.chase && stepChase(w, dt)) return endGame();
      const wet = l3 && !!w.ground?.wet && w.skin !== "wave";
      const speed =
        (w.speed + Math.min(330, w.dist / 90)) * (w.boost > 0 ? 1.35 : 1) * (w.beast > 0 ? 1.25 : 1) * (wet ? 1.3 : 1) * (w.chase && w.chase.drag > 0 ? 0.35 : 1);
      if (wet && Math.random() < 0.5) w.parts.push({ x: w.dist + PX - 20, y: w.y + R, vx: rand(-260, -80), vy: rand(-200, -60), life: 0.35, c: "#9fd4ff", s: 2.5 });
      w.boost = Math.max(0, w.boost - dt);
      w.invuln = Math.max(0, w.invuln - dt);
      w.dist += speed * dt;
      w.score += speed * dt * 0.05;
      w.runFrame += dt * speed * 0.03;
      extend(w, bossesRef.current);

      // moving platforms
      // (the ref's whistle freezes them where they are)
      if (w.frozen <= 0) for (const p of w.plats) if (p.move) p.y = p.baseY + Math.sin(w.t * p.move.spd + p.move.ph) * p.move.amp;

      // vertical
      const prevBottom = w.y + R;
      const glide = l2 && w.skin === "sakura" && w.holding && w.vy > 0;
      w.vy += G * dt * (!w.holding && w.vy < 0 ? 1.9 : glide ? 0.3 : 1) * (w.chase && w.chase.wind > 0 ? 1.3 : 1);
      if (glide) w.vy = Math.min(w.vy, 230);
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
          if (px > p.x - 6 && px < p.x + p.w + 6 && prevBottom <= p.y + (p.move ? 14 : 4) && w.y + R >= p.y) {
            w.y = p.y - R;
            w.vy = 0;
            w.ground = p;
            w.jumps = 0;
            w.land = 0.16;
            pushBoss(w, 0.006, 0); // every clean landing gains you a little
            if (l3 && p.wet && w.wetSeen !== p) {
              w.wetSeen = p;
              if (w.skin === "wave") {
                // Undertow: wet tables wash the boss back
                w.score += 50;
                addHype(w, 6);
                pushBoss(w, 0.08, 6);
                w.pops.push({ x: px + 30, y: p.y - 80, t: "UNDERTOW!", life: 0.9, c: "#9ec4e8" });
              } else w.pops.push({ x: px + 30, y: p.y - 80, t: "SLIPPERY!", life: 0.9, c: "#9fd4ff" });
            }
            if (l3 && p.move) addHype(w, 3);
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
        if (r.state === "idle" && w.beast > 0 && !r.boss && Math.abs(px - r.x) < R + 14 && w.y + R > p.y - 70) {
          // Beast Mode: straight through them
          r.state = "pinned";
          r.vx = 620;
          r.vy = -760;
          w.pins++;
          const gain = 100 * w.combo;
          w.score += gain;
          w.combo = Math.min(8, w.combo + 1);
          w.cheer = 1;
          w.shake = 0.2;
          w.pops.push({ x: px, y: w.y - 70, t: `BEAST PIN! +${gain}`, life: 1, c: "#ff6a4f" });
          pushBoss(w, 0.13, 10);
          beep(880, 0.1, "square", 0.06);
          for (let i = 0; i < 20; i++) w.parts.push({ x: r.x, y: p.y - 30, vx: rand(-300, 300), vy: rand(-400, 40), life: rand(0.3, 0.7), c: i % 2 ? "#ff4a4f" : "#f2c14e", s: rand(2, 5) });
          continue;
        }
        // (a finishing grip always engages, even straight after a respawn)
        if (r.state === "idle" && (w.invuln === 0 || r.boss?.finish) && Math.abs(px - r.x) < R + (r.boss ? 22 : 14) && w.y + R > p.y - 70) {
          w.duel = { rival: r, plat: p, t: 0, zone: 0.5, width: 0.2, speed: 4, result: null, rt: 0, ph: 0, dir: 1, pos: 0.5, move: null, z0: 0.5, w0: 0.2, flip: 1, used: false, fx: 0, two: false, lockA: null };
          newRound(w, !!r.boss);
          beep(r.boss ? 220 : 330, r.boss ? 0.3 : 0.12, "triangle", 0.06);
          return;
        }
      }

      // chalk clouds: walk into one and you can't see for a moment
      for (const c of w.clouds) {
        if (!c.got && Math.abs(c.x - px) < 46 && Math.abs(c.y - (w.y - 18)) < 52) {
          c.got = true;
          if (w.skin === "sakura") {
            // Petal Veil
            w.pops.push({ x: px, y: w.y - 90, t: "PETAL VEIL", life: 1, c: "#f3c4d2" });
            for (let i = 0; i < 12; i++) w.parts.push({ x: c.x, y: c.y, vx: rand(-200, 200), vy: rand(-200, 60), life: 0.6, c: "#f3c4d2", s: 3 });
          } else {
            w.chalk = 2.4;
            w.pops.push({ x: px, y: w.y - 90, t: "CHALK!", life: 1, c: "#ffffff" });
            beep(150, 0.2, "triangle", 0.05);
          }
        }
      }

      // power-ups
      for (const pu of w.powers) {
        if (!pu.got && Math.abs(pu.x - px) < 36 && pu.y > w.y + R - 95 && pu.y < w.y + R + 10) {
          pu.got = true;
          if (pu.kind === "shield") w.shield = true;
          else w.pw[pu.kind] = POWERS[pu.kind].secs;
          w.pops.push({ x: px, y: w.y - 90, t: POWERS[pu.kind].name.toUpperCase(), life: 1.1, c: POWERS[pu.kind].color });
          beep(1400, 0.08, "triangle", 0.05);
          setTimeout(() => beep(1800, 0.1, "triangle", 0.05), 70);
        }
      }

      // coins (the magnet pulls nearby ones in)
      for (const c of w.coinsList) {
        if (c.got) continue;
        if (w.pw.magnet > 0 || w.beast > 0) {
          const dx = px - c.x;
          const dy = w.y - 20 - c.y;
          const dd = Math.hypot(dx, dy);
          if (dd < 200 && dd > 1) {
            c.x += (dx / dd) * 700 * dt;
            c.y += (dy / dd) * 700 * dt;
          }
        }
        // close to the original hit circle: paws to chest, not the whole mane
        if (Math.abs(c.x - px) < 32 && c.y > w.y + R - 78 && c.y < w.y + R + 8) {
          c.got = true;
          let k = w.pw.x2 > 0 ? 2 : 1;
          if (l2 && w.skin === "jade" && Math.random() < 0.5) k++;
          w.coins += k;
          w.score += 10 * w.combo * (l2 && w.skin === "jade" ? 1.25 : 1);
          if (l3) addHype(w, 1.5);
          if (w.skin === "jade") pushBoss(w, 0.006, 1.2); // Jade Fortune
          else pushBoss(w, 0.003, 0.6);
          beep(1180, 0.05, "square", 0.035);
        }
      }

      // fell into the pit: back on your feet on a safe table (still, room to run, no rival)
      if (w.y > H + 80) {
        if (l2 && w.skin === "wave" && !w.waveUsed) {
          w.waveUsed = true;
          w.combo = 1;
          w.pops.push({ x: px, y: H - 140, t: "WAVE RIDER!", life: 1.2, c: "#9ec4e8" });
          beep(500, 0.2, "triangle", 0.06);
        } else if (hurt(w, "FELL!")) return endGame();
        const room = (p: Plat) => p.x + p.w - Math.max(px, p.x + 40);
        const ok = (p: Plat) => room(p) >= 140 && !p.rival?.boss;
        const safe =
          w.plats.find((p) => ok(p) && !p.move && !p.wet) ??
          w.plats.find((p) => ok(p) && !p.move) ??
          w.plats.find((p) => ok(p)) ??
          w.plats.find((p) => p.x + p.w > px + 40) ??
          w.plats[w.plats.length - 1];
        if (safe.rival && safe.rival.state === "idle" && !safe.rival.boss) safe.rival.state = "gone";
        const standX = Math.max(px, safe.x + 40);
        w.dist = standX - PX;
        w.y = safe.y - R;
        w.vy = 0;
        w.ground = safe;
        w.jumps = 0;
        w.coyote = 0;
        w.holding = false;
        w.invuln = 1.6;
        for (let i = 0; i < 14; i++) w.parts.push({ x: standX, y: safe.y - rand(0, 60), vx: rand(-120, 120), vy: rand(-220, -40), life: 0.5, c: "#f2e1b6", s: 3 });
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
      if (w.banner && (w.banner.life -= dt) <= 0) w.banner = null;
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

    /** Crimson Peak ledge: dark stone with a snow cap and icicles; static ones stand on a pillar. */
    const drawLedge = (p: Plat, cam: number) => {
      const x = p.x - cam;
      if (!p.move) {
        const pg = ctx.createLinearGradient(x, 0, x + p.w, 0);
        pg.addColorStop(0, "#14161f");
        pg.addColorStop(0.5, "#1d2030");
        pg.addColorStop(1, "#11131b");
        ctx.fillStyle = pg;
        ctx.fillRect(x + p.w * 0.22, p.y + 20, p.w * 0.56, H - p.y);
        ctx.fillStyle = "rgba(255,255,255,.04)";
        for (let yy = p.y + 40; yy < H; yy += 34) ctx.fillRect(x + p.w * 0.22, yy, p.w * 0.56, 2);
      } else {
        // a faint glow under floating ledges
        const gl = ctx.createRadialGradient(x + p.w / 2, p.y + 34, 4, x + p.w / 2, p.y + 34, p.w * 0.5);
        gl.addColorStop(0, "rgba(255,74,79,.28)");
        gl.addColorStop(1, "rgba(255,74,79,0)");
        ctx.fillStyle = gl;
        ctx.fillRect(x - 20, p.y, p.w + 40, 80);
      }
      const g = ctx.createLinearGradient(0, p.y, 0, p.y + 28);
      g.addColorStop(0, "#2b2f42");
      g.addColorStop(1, "#141621");
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.roundRect(x, p.y, p.w, 28, 5);
      ctx.fill();
      ctx.strokeStyle = "rgba(0,0,0,.5)";
      ctx.lineWidth = 1;
      for (let bx = x + 46; bx < x + p.w - 10; bx += 52) {
        ctx.beginPath();
        ctx.moveTo(bx, p.y + 6);
        ctx.lineTo(bx, p.y + 28);
        ctx.stroke();
      }
      // snow cap with lumps
      ctx.fillStyle = "#e8eef8";
      ctx.beginPath();
      ctx.moveTo(x - 2, p.y + 5);
      for (let sx = x; sx <= x + p.w + 2; sx += 14) ctx.quadraticCurveTo(sx + 7, p.y - 5 - ((sx * 7) % 4), sx + 14, p.y + 3);
      ctx.lineTo(x + p.w + 2, p.y + 7);
      ctx.lineTo(x - 2, p.y + 7);
      ctx.fill();
      // icicles
      ctx.fillStyle = "rgba(200,225,255,.75)";
      for (let ix = x + 10; ix < x + p.w - 6; ix += 23) {
        const len = 6 + ((ix * 13) % 9);
        ctx.beginPath();
        ctx.moveTo(ix, p.y + 27);
        ctx.lineTo(ix + 3, p.y + 27 + len);
        ctx.lineTo(ix + 6, p.y + 27);
        ctx.fill();
      }
      // a red lantern on some static ledges
      if (!p.move && Math.round(p.x) % 3 === 0) {
        const lx = x + 18;
        ctx.strokeStyle = "#3a2a20";
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.moveTo(lx, p.y);
        ctx.lineTo(lx, p.y - 46);
        ctx.stroke();
        const lg = ctx.createRadialGradient(lx, p.y - 52, 2, lx, p.y - 52, 26);
        lg.addColorStop(0, "rgba(255,120,80,.55)");
        lg.addColorStop(1, "rgba(255,80,60,0)");
        ctx.fillStyle = lg;
        ctx.fillRect(lx - 26, p.y - 78, 52, 52);
        ctx.fillStyle = "#d42a2f";
        ctx.beginPath();
        ctx.ellipse(lx, p.y - 52, 8, 10, 0, 0, Math.PI * 2);
        ctx.fill();
      }
    };

    /** The Arena: a black stage table with a gold rim and a red LED strip; wet ones have a puddle. */
    const drawStage = (p: Plat, cam: number, t: number) => {
      const x = p.x - cam;
      if (!p.move) {
        // steel truss legs
        ctx.strokeStyle = "#2a2730";
        ctx.lineWidth = 3;
        for (const lx of [x + 22, x + p.w - 22]) {
          ctx.beginPath();
          ctx.moveTo(lx, p.y + 22);
          ctx.lineTo(lx, H);
          ctx.stroke();
        }
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        for (let yy = p.y + 22; yy < H; yy += 40) {
          ctx.moveTo(x + 22, yy);
          ctx.lineTo(x + p.w - 22, yy + 40);
          ctx.moveTo(x + p.w - 22, yy);
          ctx.lineTo(x + 22, yy + 40);
        }
        ctx.stroke();
      } else {
        // a hanging rig: cables up into the dark
        ctx.strokeStyle = "rgba(160,150,170,.35)";
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.moveTo(x + 14, p.y);
        ctx.lineTo(x + 14, 0);
        ctx.moveTo(x + p.w - 14, p.y);
        ctx.lineTo(x + p.w - 14, 0);
        ctx.stroke();
      }
      const g = ctx.createLinearGradient(0, p.y, 0, p.y + 24);
      g.addColorStop(0, "#26222c");
      g.addColorStop(1, "#0c0b10");
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.roundRect(x, p.y, p.w, 24, 5);
      ctx.fill();
      ctx.fillStyle = "#f2c14e";
      ctx.fillRect(x + 3, p.y, p.w - 6, 3);
      // LED strip (chases along the edge)
      for (let lx = x + 8; lx < x + p.w - 8; lx += 12) {
        const on = (Math.floor(lx / 12 + t * 10) % 6) < 2;
        ctx.fillStyle = on ? "#ff3b41" : "rgba(255,59,65,.25)";
        ctx.fillRect(lx, p.y + 14, 6, 3);
      }
      if (p.wet) {
        // a puddle with a moving sheen
        ctx.save();
        ctx.beginPath();
        ctx.ellipse(x + p.w / 2, p.y + 1, p.w * 0.42, 5, 0, 0, Math.PI * 2);
        ctx.clip();
        const sg = ctx.createLinearGradient(x, 0, x + p.w, 0);
        const k = (t * 0.6) % 1;
        sg.addColorStop(0, "rgba(120,190,255,.45)");
        sg.addColorStop(Math.max(0, k - 0.1), "rgba(120,190,255,.45)");
        sg.addColorStop(k, "rgba(230,245,255,.95)");
        sg.addColorStop(Math.min(1, k + 0.1), "rgba(120,190,255,.45)");
        sg.addColorStop(1, "rgba(120,190,255,.45)");
        ctx.fillStyle = sg;
        ctx.fillRect(x, p.y - 6, p.w, 12);
        ctx.restore();
        // drips
        ctx.fillStyle = "rgba(140,200,255,.7)";
        for (let dx = x + 30; dx < x + p.w - 20; dx += 47) {
          const dy = ((t * 60 + dx) % 40);
          ctx.fillRect(dx, p.y + 24 + dy, 2, 4);
        }
      }
    };

    const drawCloud = (c: Cloud, cam: number, t: number) => {
      const x = c.x - cam;
      if (x < -80 || x > W + 80) return;
      const y = c.y + Math.sin(t * 1.5 + c.x) * 5;
      ctx.fillStyle = "rgba(245,242,235,.82)";
      for (const [ox, oy, r] of [[-22, 6, 20], [0, -4, 26], [22, 6, 20], [10, 12, 18], [-10, 12, 18]] as const) {
        ctx.beginPath();
        ctx.arc(x + ox + Math.sin(t * 2 + ox) * 2, y + oy, r, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.fillStyle = "rgba(20,18,22,.55)";
      ctx.font = "900 12px 'Chakra Petch', monospace";
      ctx.textAlign = "center";
      ctx.fillText("CHALK", x, y + 8);
    };

    /** The Arena crowd along the bottom: silhouettes with phone lights; they jump when the crowd is hyped. */
    const drawCrowd = (w: World, cam: number) => {
      const hype = Math.max(w.cheer, w.beast > 0 ? 1 : 0, w.hype / 140);
      for (let i = 0; i < 34; i++) {
        const sx = (((i * 61 - cam * 0.6) % (W + 60)) + W + 60) % (W + 60) - 30;
        const jump = Math.max(0, Math.sin(w.t * (7 + (i % 5)) + i * 1.7)) * 14 * hype;
        const base = H - 6 - (i % 3) * 7 - jump;
        ctx.fillStyle = i % 2 ? "#050407" : "#0a080d";
        ctx.beginPath();
        ctx.arc(sx, base - 26, 9, 0, Math.PI * 2);
        ctx.fill();
        ctx.beginPath();
        ctx.roundRect(sx - 14, base - 17, 28, 30, 9);
        ctx.fill();
        if (i % 3 === 0 || hype > 0.6) {
          // an arm up (with a phone light)
          ctx.strokeStyle = ctx.fillStyle;
          ctx.lineWidth = 5;
          ctx.lineCap = "round";
          ctx.beginPath();
          ctx.moveTo(sx + 9, base - 12);
          ctx.lineTo(sx + 14, base - 44);
          ctx.stroke();
          ctx.fillStyle = `rgba(255,248,220,${0.55 + Math.sin(w.t * 3 + i) * 0.25})`;
          ctx.fillRect(sx + 12, base - 50, 4, 6);
        }
      }
    };

    /** A boss's face in a circle: from the cartoon art (face sits upper-middle) or a photo/card (top crop). */
    const drawFace = (img: HTMLImageElement, art: boolean, cx: number, cy: number, rr: number) => {
      const iw = img.naturalWidth;
      const ih = img.naturalHeight;
      if (art) {
        // the face in the boss art: roughly x 30-62%, y 4-36% of the square
        ctx.drawImage(img, iw * 0.3, ih * 0.04, iw * 0.32, ih * 0.32, cx - rr, cy - rr, rr * 2, rr * 2);
        return;
      }
      const s2 = Math.max((rr * 2) / iw, (rr * 2) / (ih * 0.55));
      const dw = iw * s2;
      ctx.drawImage(img, cx - dw / 2, cy - rr - ih * s2 * 0.08, dw, ih * s2);
    };

    /** A boss: a bigger rival with the Riser's portrait, name and remaining grip (hp). */
    const drawBoss = (r: Rival, p: Plat, cam: number) => {
      const bf = r.boss!;
      const x = r.x - cam;
      const base = r.state === "pinned" ? p.y + r.y : p.y;
      ctx.save();
      ctx.translate(x, base);
      if (r.state === "pinned") ctx.rotate(r.spin);
      ctx.scale(1.55, 1.55);
      // body
      ctx.fillStyle = "#16121a";
      ctx.strokeStyle = "#f2c14e";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.roundRect(-16, -64, 32, 46, 9);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = "#d42a2f";
      ctx.fillRect(-16, -48, 32, 6);
      // big flexed arm
      ctx.strokeStyle = "#2a2230";
      ctx.lineWidth = 11;
      ctx.lineCap = "round";
      ctx.beginPath();
      ctx.moveTo(-12, -52);
      ctx.lineTo(-34, -42);
      ctx.lineTo(-38, -70);
      ctx.stroke();
      ctx.restore();
      // portrait head
      const hx = x;
      const hy = base - 124;
      const rr = 24;
      ctx.save();
      ctx.beginPath();
      ctx.arc(hx, hy, rr, 0, Math.PI * 2);
      ctx.fillStyle = "#2a2230";
      ctx.fill();
      ctx.clip();
      const img = bossImgs.current[bf.b.id];
      if (img?.complete && img.naturalWidth) {
        drawFace(img, !!bf.b.art, hx, hy, rr);
      } else {
        ctx.fillStyle = "#efe7d6";
        ctx.font = "900 22px 'Saira Extra Condensed', Impact, sans-serif";
        ctx.textAlign = "center";
        ctx.fillText(bf.b.name.split(" ").map((w) => w[0]).join("").slice(0, 2).toUpperCase(), hx, hy + 8);
      }
      ctx.restore();
      ctx.strokeStyle = "#f2c14e";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(hx, hy, rr, 0, Math.PI * 2);
      ctx.stroke();
      if (r.state === "idle") {
        // name tag + grip pips
        const label = `#${String(bf.b.id).padStart(3, "0")} ${bf.b.name.split(" ")[0].toUpperCase()}`;
        ctx.font = "900 17px 'Saira Extra Condensed', Impact, sans-serif";
        const tw = ctx.measureText(label).width + 22;
        ctx.fillStyle = "rgba(125,18,22,.92)";
        ctx.beginPath();
        ctx.roundRect(hx - tw / 2, hy - rr - 34, tw, 24, 6);
        ctx.fill();
        ctx.fillStyle = "#fff4cf";
        ctx.textAlign = "center";
        ctx.fillText(label, hx, hy - rr - 16);
        ctx.font = "700 11px 'Chakra Petch', monospace";
        ctx.fillStyle = "#f2c14e";
        ctx.fillText(bf.sm ? "SUPERMATCH" : "BOSS", hx, hy - rr - 40);
      }
    };

    const drawPower = (pu: Power, cam: number, t: number) => {
      const x = pu.x - cam;
      if (x < -30 || x > W + 30) return;
      const y = pu.y + Math.sin(t * 3 + pu.x) * 6;
      const def = POWERS[pu.kind];
      const g = ctx.createRadialGradient(x, y, 2, x, y, 30);
      g.addColorStop(0, def.color + "aa");
      g.addColorStop(1, def.color + "00");
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(x, y, 30, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "#120f14";
      ctx.strokeStyle = def.color;
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(x, y, 17, 0, Math.PI * 2);
      ctx.fill();
      ctx.stroke();
      ctx.fillStyle = def.color;
      ctx.font = "900 16px 'Saira Extra Condensed', Impact, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(def.icon, x, y + 6);
    };

    const drawRival = (r: Rival, p: Plat, cam: number) => {
      if (r.state === "gone") return;
      if (r.boss) return drawBoss(r, p, cam);
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

    const drawThrow = (t: Throw, cam: number) => {
      const x = t.x - cam;
      if (x < -40 || x > W + 40) return;
      ctx.save();
      ctx.translate(x, t.y);
      ctx.rotate(t.spin);
      if (t.kind === "bottle") {
        ctx.fillStyle = "rgba(150,220,200,.85)";
        ctx.beginPath();
        ctx.roundRect(-6, -14, 12, 24, 4);
        ctx.fill();
        ctx.fillRect(-3, -20, 6, 7);
        ctx.fillStyle = "#3a8bd6";
        ctx.fillRect(-6, -4, 12, 6);
      } else {
        ctx.fillStyle = "#f4f1ea";
        ctx.beginPath();
        ctx.ellipse(0, 0, 11, 9, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = "#c9c2b4";
        ctx.fillRect(-3, -12, 6, 5);
      }
      ctx.restore();
      if (t.kind === "chalk") {
        ctx.fillStyle = "rgba(255,255,255,.25)";
        ctx.beginPath();
        ctx.arc(x - t.vx * 0.03, t.y - t.vy * 0.03, 8, 0, Math.PI * 2);
        ctx.fill();
      }
    };

    /** Boss art with its square edges faded out (made once per boss). */
    const faded: Record<number, HTMLCanvasElement> = {};
    const fadedArt = (id: number, img: HTMLImageElement) => {
      if (faded[id]) return faded[id];
      const n = 360;
      const cv2 = document.createElement("canvas");
      cv2.width = cv2.height = n;
      const c2 = cv2.getContext("2d")!;
      c2.drawImage(img, 0, 0, n, n);
      c2.globalCompositeOperation = "destination-in";
      const m = c2.createRadialGradient(n / 2, n * 0.45, n * 0.26, n / 2, n * 0.5, n * 0.5);
      m.addColorStop(0, "rgba(0,0,0,1)");
      m.addColorStop(1, "rgba(0,0,0,0)");
      c2.fillStyle = m;
      c2.fillRect(0, 0, n, n);
      faded[id] = cv2;
      return cv2;
    };

    /** The chasing Riser, huge, closing in from the left (just peeking in when far back). */
    const drawChaser = (w: World) => {
      const c = w.chase!;
      const size = 290;
      const x = -230 + Math.min(1, c.prox) * (PX - 60);
      const bob = Math.sin(w.t * 9) * 6;
      const y = H - size + 30 + bob;
      // red danger glow when they're close
      const g = ctx.createRadialGradient(x + size / 2, y + size / 2, 20, x + size / 2, y + size / 2, size * 0.75);
      g.addColorStop(0, `rgba(255,40,40,${0.12 + c.prox * 0.3 + (c.warn > 0 ? 0.15 : 0)})`);
      g.addColorStop(1, "rgba(255,40,40,0)");
      ctx.fillStyle = g;
      ctx.fillRect(x - 100, y - 100, size + 200, size + 200);
      const img = bossImgs.current[c.b.id];
      ctx.save();
      ctx.globalAlpha = 0.95;
      if (c.warn > 0 && Math.floor(w.t * 14) % 2) ctx.filter = "brightness(1.8) saturate(1.4)";
      if (img?.complete && img.naturalWidth) {
        if (c.b.art) ctx.drawImage(fadedArt(c.b.id, img), x, y, size, size);
        else {
          ctx.beginPath();
          ctx.arc(x + size / 2, y + size / 2, size / 2.4, 0, Math.PI * 2);
          ctx.clip();
          drawFace(img, false, x + size / 2, y + size / 2, size / 2.4);
        }
      } else {
        ctx.fillStyle = "#2a2230";
        ctx.beginPath();
        ctx.arc(x + size / 2, y + size / 2, size / 2.6, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = "#efe7d6";
        ctx.font = "900 80px 'Saira Extra Condensed', Impact, sans-serif";
        ctx.textAlign = "center";
        ctx.fillText(c.b.name.split(" ").map((p) => p[0]).join("").slice(0, 2), x + size / 2, y + size / 2 + 28);
      }
      ctx.restore();
      if (c.prox > 0.72) {
        ctx.fillStyle = `rgba(255,74,79,${0.6 + Math.sin(w.t * 16) * 0.3})`;
        ctx.font = "900 26px 'Saira Extra Condensed', Impact, sans-serif";
        ctx.textAlign = "center";
        ctx.fillText("RUN!", PX - 70, H - 150);
      }
    };

    const drawDuel = (w: World) => {
      const d = w.duel!;
      ctx.fillStyle = "rgba(8,7,6,.55)";
      ctx.fillRect(0, 0, W, H);
      const cx = W / 2;
      const cy = 150;
      ctx.fillStyle = "rgba(16,14,11,.94)";
      ctx.strokeStyle = d.result === "pin" || d.result === "hit" ? "#d5b67a" : d.result === "miss" ? "#d42a2f" : d.rival.boss ? "#f2c14e" : "rgba(213,182,122,.4)";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.roundRect(cx - 310, cy - 100, 620, 360, 22);
      ctx.fill();
      ctx.stroke();
      ctx.textAlign = "center";
      ctx.fillStyle = "#efe7d6";
      ctx.font = "900 46px 'Saira Extra Condensed', Impact, sans-serif";
      const bf = d.rival.boss;
      if (bf) {
        const mv = d.move ? MOVES[d.move] : null;
        const calling = mv && !d.result && d.t < 1;
        if (calling) {
          // the call-out: "BHAVYA'S PRESS!"
          const pop = 1 + Math.max(0, 0.25 - d.t) * 1.6;
          ctx.save();
          ctx.translate(cx, cy - 40);
          ctx.scale(pop, pop);
          ctx.fillStyle = mv.color;
          ctx.fillText(`${bf.b.name.split(" ")[0].toUpperCase()}'S ${mv.name.toUpperCase()}!`, 0, 0);
          ctx.restore();
        } else {
          const title = bf.sm
            ? d.result === "pin" ? "CHAMPION!" : d.result === "miss" ? "ROUND TO " + bf.b.name.split(" ")[0].toUpperCase() : d.result === "hit" ? "ROUND TO YOU!" : `SUPERMATCH: ${bf.b.name.toUpperCase()}`
            : d.result === "pin" ? "BOSS PINNED!" : d.result === "miss" ? "SLAMMED!" : d.result === "hit" ? "GOOD GRIP!" : `BOSS: ${bf.b.name.toUpperCase()}`;
          ctx.fillText(title, cx, cy - 40);
        }
        ctx.font = "700 14px 'Chakra Petch', monospace";
        ctx.fillStyle = mv ? mv.color : "#d5b67a";
        ctx.fillText(mv ? `${moveOf(bf.b.id) === "chain" ? `${MOVES.chain.name} ${bf.max - bf.hp + 1}/${bf.max} · ` : ""}${mv.name}: ${mv.tip}`.toUpperCase() : `RISER #${String(bf.b.id).padStart(3, "0")} · ${bf.max} GOOD GRIPS TO PIN`, cx, cy - 12);
        // the full boss art on the right, like a fighting-game portrait
        const artImg = bf.b.art ? bossImgs.current[bf.b.id] : undefined;
        if (artImg?.complete && artImg.naturalWidth) {
          const aw = 160;
          const ax = cx + 296 - aw + (d.fx > 0 ? rand(-1, 1) * d.fx * 30 : 0);
          const ay = cy + 86 + (d.fx > 0 ? rand(-1, 1) * d.fx * 20 : 0);
          ctx.save();
          ctx.beginPath();
          ctx.roundRect(ax, ay, aw, aw, 14);
          ctx.clip();
          ctx.drawImage(artImg, ax, ay, aw, aw);
          ctx.restore();
          ctx.strokeStyle = "rgba(242,193,78,.6)";
          ctx.lineWidth = 2;
          ctx.beginPath();
          ctx.roundRect(ax, ay, aw, aw, 14);
          ctx.stroke();
        }
        // the Riser's portrait, name and grips landed
        const px2 = cx - 228;
        const py2 = cy + 128;
        const rr = 46;
        ctx.save();
        ctx.beginPath();
        ctx.arc(px2, py2, rr, 0, Math.PI * 2);
        ctx.fillStyle = "#2a2230";
        ctx.fill();
        ctx.clip();
        const img = bossImgs.current[bf.b.id];
        if (img?.complete && img.naturalWidth) {
          drawFace(img, !!bf.b.art, px2, py2, rr);
        } else {
          ctx.fillStyle = "#efe7d6";
          ctx.font = "900 34px 'Saira Extra Condensed', Impact, sans-serif";
          ctx.fillText(bf.b.name.split(" ").map((w2) => w2[0]).join("").slice(0, 2).toUpperCase(), px2, py2 + 12);
        }
        ctx.restore();
        ctx.strokeStyle = "#f2c14e";
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.arc(px2, py2, rr, 0, Math.PI * 2);
        ctx.stroke();
        ctx.textAlign = "center";
        if (bf.sm) {
          // best of three: YOU 1 – 0 ERICK
          const you = bf.max - bf.hp;
          const them = bf.lost ?? 0;
          ctx.font = "900 26px 'Saira Extra Condensed', Impact, sans-serif";
          ctx.fillStyle = "#f2c14e";
          ctx.fillText(`${you} – ${them}`, px2, py2 + rr + 30);
          ctx.font = "700 10px 'Chakra Petch', monospace";
          ctx.fillStyle = "#d5b67a";
          ctx.fillText(`YOU · ${bf.b.name.split(" ")[0].toUpperCase()} · ${bf.max === 1 ? "YOU NEED 1" : "FIRST TO 2"}`, px2, py2 + rr + 46);
        } else
          for (let i = 0; i < bf.max; i++) {
            ctx.fillStyle = i < bf.max - bf.hp ? "#f2c14e" : "#2a251d";
            ctx.strokeStyle = "#f2c14e";
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.arc(px2 - (bf.max - 1) * 13 + i * 26, py2 + rr + 20, 8, 0, Math.PI * 2);
            ctx.fill();
            ctx.stroke();
          }
      } else {
        ctx.fillText(d.result === "pin" ? (d.two ? "DOUBLE PIN!" : "PIN!") : d.result === "miss" ? "SLIPPED!" : d.two ? "DOUBLE GRIP" : "GRIP FIGHT", cx, cy - 40);
        ctx.font = "700 14px 'Chakra Petch', monospace";
        ctx.fillStyle = "#d5b67a";
        if (!d.result)
          ctx.fillText(d.two ? (d.lockA === null ? "LOCK BOTH HANDS: TAP GOLD · HAND 1 OF 2" : "FIRST HAND LOCKED · NOW HAND 2") : "TAP WHEN THE NEEDLE HITS GOLD", cx, cy - 12);
      }
      const bw = 520;
      const bx = cx - bw / 2;
      const by = cy + 10;
      ctx.fillStyle = "#16130f";
      ctx.beginPath();
      ctx.roundRect(bx, by, bw, 30, 15);
      ctx.fill();
      const zx = bx + bw * (d.zone - d.width / 2);
      const zw = bw * d.width;
      // King's Move: the zone blinks out (a faint outline is all you get)
      const hidden = d.move === "kings" && !d.result && d.t % 1.1 > 0.62;
      if (hidden) {
        ctx.strokeStyle = "rgba(213,182,122,.18)";
        ctx.lineWidth = 1;
        ctx.strokeRect(zx, by + 3, zw, 24);
      } else {
        ctx.fillStyle = d.move === "press" && !d.result ? `rgb(${213 + Math.min(42, d.t * 30)},${182 - Math.min(80, d.t * 60)},${122 - Math.min(70, d.t * 50)})` : "#d5b67a";
        ctx.fillRect(zx, by + 3, zw, 24);
      }
      if (d.move === "press" && !d.result) {
        // jaws closing in on the zone
        ctx.fillStyle = "#ff7a3d";
        for (const [ex, sgn] of [[zx, -1], [zx + zw, 1]] as const) {
          ctx.beginPath();
          ctx.moveTo(ex + sgn * 2, by + 15);
          ctx.lineTo(ex + sgn * 14, by + 5);
          ctx.lineTo(ex + sgn * 14, by + 25);
          ctx.closePath();
          ctx.fill();
        }
      }
      if (d.two && d.lockA !== null) {
        // the first hand, locked in place
        ctx.fillStyle = "#f2c14e";
        ctx.fillRect(bx + bw * d.lockA - 3, by - 8, 6, 46);
        ctx.font = "900 13px 'Saira Extra Condensed', Impact, sans-serif";
        ctx.textAlign = "center";
        ctx.fillText("✓", bx + bw * d.lockA, by - 12);
      }
      const nx = bx + bw * d.pos;
      ctx.fillStyle = d.result === "pin" || d.result === "hit" ? "#f2e1b6" : d.result === "miss" ? "#ff4a4f" : "#ffffff";
      ctx.fillRect(nx - 3, by - 8, 6, 46);
      // the grip: two forearms meeting
      const tilt =
        d.result === "pin" ? -0.9 * Math.min(1, d.rt * 4) : d.result === "hit" ? -0.35 * Math.min(1, d.rt * 4) : d.result === "miss" ? 0.9 * Math.min(1, d.rt * 4) : Math.sin(d.t * 18) * 0.06;
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
      if (w.chase && w.chase.tilt > 0) {
        // Toproll: the whole arena rolls
        const k = Math.min(1, w.chase.tilt * 2, (MOVE_SECS - w.chase.tilt) * 3);
        ctx.translate(W / 2, H / 2);
        ctx.rotate(Math.sin(w.t * 1.3) * 0.14 * k);
        ctx.translate(-W / 2, -H / 2);
      }
      const l2 = w.level === 2;
      const l3 = w.level === 3;
      // sky
      const g = ctx.createLinearGradient(0, 0, 0, H);
      g.addColorStop(0, l3 ? "#0d0a14" : l2 ? "#0b1024" : "#160d0c");
      g.addColorStop(0.6, l3 ? "#08070b" : l2 ? "#0b0d18" : "#0a0908");
      g.addColorStop(1, l3 ? "#050407" : l2 ? "#07080f" : "#120a09");
      ctx.fillStyle = g;
      ctx.fillRect(-20, -20, W + 40, H + 40);
      const bg = l3 ? imgs.current.l3bg : imgs.current.l2bg;
      if ((l2 || l3) && bg?.complete && bg.naturalWidth) {
        const tw = bg.naturalWidth;
        const off = -(((cam * 0.08) % tw) + tw) % tw;
        ctx.drawImage(bg, off, -20, tw, H + 20);
        ctx.drawImage(bg, off + tw, -20, tw, H + 20);
      }
      if (l3) {
        // sweeping spotlights (they flash red in Beast Mode)
        ctx.save();
        ctx.globalCompositeOperation = "lighter";
        for (let i = 0; i < 3; i++) {
          const ox = W * (0.2 + i * 0.3);
          const a = Math.sin(w.t * (0.5 + i * 0.17) + i * 2) * 0.55;
          ctx.save();
          ctx.translate(ox, -10);
          ctx.rotate(a);
          const sg = ctx.createLinearGradient(0, 0, 0, H);
          const col = w.beast > 0 ? "255,60,60" : i === 1 ? "255,90,90" : "255,240,210";
          sg.addColorStop(0, `rgba(${col},${0.2 + w.cheer * 0.08})`);
          sg.addColorStop(1, `rgba(${col},0)`);
          ctx.fillStyle = sg;
          ctx.beginPath();
          ctx.moveTo(-6, 0);
          ctx.lineTo(6, 0);
          ctx.lineTo(90, H);
          ctx.lineTo(-90, H);
          ctx.closePath();
          ctx.fill();
          ctx.restore();
        }
        ctx.restore();
      }
      if (!l2 && !l3) {
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
      }
      // pit haze
      const fog = ctx.createLinearGradient(0, H - 110, 0, H);
      fog.addColorStop(0, l3 ? "rgba(242,193,78,0)" : l2 ? "rgba(120,140,200,0)" : "rgba(212,42,47,0)");
      fog.addColorStop(1, l3 ? "rgba(212,42,47,.2)" : l2 ? "rgba(150,170,230,.22)" : "rgba(212,42,47,.25)");
      ctx.fillStyle = fog;
      ctx.fillRect(0, H - 110, W, 110);
      if (l3) drawCrowd(w, cam);
      if (w.chase) drawChaser(w);
      if (l2) {
        // drifting snow and crimson petals
        for (let i = 0; i < 46; i++) {
          const sp = 20 + ((i * 37) % 40);
          const fx2 = (((i * 211 - cam * (0.3 + (i % 3) * 0.15) - w.t * 30) % (W + 40)) + W + 40) % (W + 40) - 20;
          const fy2 = (((i * 97 + w.t * sp) % (H + 20)) + H + 20) % (H + 20) - 10;
          ctx.globalAlpha = 0.5 + (i % 4) * 0.12;
          if (i % 3 === 0) {
            ctx.fillStyle = "#e0405a";
            ctx.beginPath();
            ctx.ellipse(fx2 + Math.sin(w.t * 2 + i) * 6, fy2, 3.2, 1.8, w.t * 2 + i, 0, Math.PI * 2);
            ctx.fill();
          } else {
            ctx.fillStyle = "#eef3ff";
            ctx.fillRect(fx2, fy2, 2, 2);
          }
        }
        ctx.globalAlpha = 1;
      }

      for (const p of w.plats) if (p.x - cam < W + 40 && p.x + p.w - cam > -40) (l3 ? drawStage(p, cam, w.t) : l2 ? drawLedge(p, cam) : drawTable(p, cam));
      for (const c of w.clouds) if (!c.got) drawCloud(c, cam, w.t);
      for (const t of w.throws) drawThrow(t, cam);
      for (const pu of w.powers) if (!pu.got) drawPower(pu, cam, w.t);
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
      if (w.beast > 0) {
        // Beast Mode: a red-gold fire around the lion
        const by = w.y + R - 45;
        const bgr = ctx.createRadialGradient(PX, by, 10, PX, by, 95 + Math.sin(w.t * 20) * 8);
        bgr.addColorStop(0, "rgba(255,200,80,.55)");
        bgr.addColorStop(0.5, "rgba(255,60,40,.35)");
        bgr.addColorStop(1, "rgba(255,40,40,0)");
        ctx.fillStyle = bgr;
        ctx.beginPath();
        ctx.arc(PX, by, 110, 0, Math.PI * 2);
        ctx.fill();
        if (Math.random() < 0.8) w.parts.push({ x: w.dist + PX + rand(-40, 30), y: w.y + R - rand(10, 80), vx: rand(-260, -120), vy: rand(-160, -40), life: 0.4, c: Math.random() < 0.5 ? "#ff4a2f" : "#f2c14e", s: rand(2, 4) });
      }
      drawFx(ctx, fx.current, cam, "back");
      drawPlayer(w);
      drawFx(ctx, fx.current, cam, "front");
      if (w.shield || w.pw.magnet > 0) {
        const cy = w.y + R - 48;
        ctx.save();
        ctx.lineWidth = 3;
        if (w.shield) {
          ctx.strokeStyle = `rgba(127,200,255,${0.55 + Math.sin(w.t * 6) * 0.2})`;
          ctx.fillStyle = "rgba(127,200,255,.08)";
          ctx.beginPath();
          ctx.ellipse(PX, cy, 74, 60, 0, 0, Math.PI * 2);
          ctx.fill();
          ctx.stroke();
        }
        if (w.pw.magnet > 0) {
          ctx.setLineDash([6, 10]);
          ctx.lineDashOffset = -w.t * 40;
          ctx.strokeStyle = "rgba(255,90,95,.45)";
          ctx.beginPath();
          ctx.arc(PX, cy, 110, 0, Math.PI * 2);
          ctx.stroke();
        }
        ctx.restore();
      }
      ctx.textAlign = "center";
      ctx.font = "900 30px 'Saira Extra Condensed', Impact, sans-serif";
      for (const p of w.pops) {
        ctx.globalAlpha = Math.min(1, p.life * 2);
        ctx.fillStyle = p.c;
        ctx.fillText(p.t, p.x - cam, p.y);
      }
      ctx.globalAlpha = 1;
      ctx.restore();

      if (l3) {
        if (w.chalk > 0) {
          // chalk in your eyes: a white haze that only clears near the lion
          const a = Math.min(1, w.chalk / 0.6) * 0.84;
          const cg = ctx.createRadialGradient(PX, w.y - 10, 80, PX, w.y - 10, 320);
          cg.addColorStop(0, `rgba(245,242,235,${a * 0.08})`);
          cg.addColorStop(1, `rgba(245,242,235,${a})`);
          ctx.fillStyle = cg;
          ctx.fillRect(0, 0, W, H);
        }
        if (w.beast > 0) {
          const vg = ctx.createRadialGradient(W / 2, H / 2, H * 0.35, W / 2, H / 2, W * 0.65);
          vg.addColorStop(0, "rgba(255,40,40,0)");
          vg.addColorStop(1, `rgba(255,40,40,${0.28 + Math.sin(w.t * 10) * 0.08})`);
          ctx.fillStyle = vg;
          ctx.fillRect(0, 0, W, H);
        }
        if (w.frozen > 0) {
          ctx.fillStyle = `rgba(160,200,255,${Math.min(0.18, w.frozen * 0.2)})`;
          ctx.fillRect(0, 0, W, H);
        }
        const c = w.chase;
        if (c && c.dark > 0) {
          // King's Move: lights out, a small pool of light around the lion
          const k = Math.min(1, c.dark * 2, (MOVE_SECS - c.dark) * 4) * (w.skin === "sakura" ? 0.5 : 1); // Petal Veil
          const dg = ctx.createRadialGradient(PX + 60, w.y - 10, 70, PX + 60, w.y - 10, 260);
          dg.addColorStop(0, "rgba(0,0,0,0)");
          dg.addColorStop(1, `rgba(0,0,0,${0.95 * k})`);
          ctx.fillStyle = dg;
          ctx.fillRect(0, 0, W, H);
        }
        if (c && c.wind > 0) {
          ctx.strokeStyle = "rgba(200,170,255,.35)";
          ctx.lineWidth = 2;
          for (let i = 0; i < 14; i++) {
            const yy = (i * 41 + w.t * 30) % H;
            const xx = W - ((w.t * 900 + i * 173) % (W + 200));
            ctx.beginPath();
            ctx.moveTo(xx, yy);
            ctx.lineTo(xx + 80, yy + 18);
            ctx.stroke();
          }
        }
      }

      // HUD
      ctx.textAlign = "left";
      ctx.font = "900 34px 'Saira Extra Condensed', Impact, sans-serif";
      ctx.fillStyle = "#efe7d6";
      ctx.fillText(String(Math.floor(w.score)).padStart(6, "0"), 24, 46);
      ctx.font = "700 13px 'Chakra Petch', monospace";
      ctx.fillStyle = "#d5b67a";
      ctx.fillText(`${w.level === 3 ? "LV.3 THE ARENA   " : w.level === 2 ? "LV.2 CRIMSON PEAK   " : ""}PINS ${w.pins}   TEMPLE COINS ${w.coins}${w.combo > 1 ? `   COMBO x${w.combo}` : ""}`, 24, 68);
      // active power-ups
      let ix = 24;
      const active: [string, string, number][] = [];
      if (w.shield) active.push([POWERS.shield.icon, POWERS.shield.color, 1]);
      for (const k of ["magnet", "x2"] as const) if (w.pw[k] > 0) active.push([POWERS[k].icon, POWERS[k].color, w.pw[k] / POWERS[k].secs]);
      for (const [icon, col, f] of active) {
        ctx.fillStyle = "rgba(10,9,8,.7)";
        ctx.beginPath();
        ctx.roundRect(ix, 80, 58, 26, 8);
        ctx.fill();
        ctx.fillStyle = col;
        ctx.font = "900 15px 'Saira Extra Condensed', Impact, sans-serif";
        ctx.textAlign = "left";
        ctx.fillText(icon, ix + 8, 99);
        ctx.fillRect(ix + 26, 91, 24 * f, 5);
        ix += 64;
      }
      if (onAirRef.current && !mutedRef.current) {
        ctx.textAlign = "left";
        ctx.font = "700 11px 'Chakra Petch', monospace";
        ctx.fillStyle = "rgba(242,225,182,.7)";
        ctx.fillText(`♪ ${station.current.freq} FM · ${station.current.name.toUpperCase()}`, 24, H - 18);
      }
      if (l3) {
        // the hype meter (top middle); full = Beast Mode
        const mw = 260;
        const mx = W / 2 - mw / 2;
        ctx.fillStyle = "rgba(10,9,8,.75)";
        ctx.beginPath();
        ctx.roundRect(mx - 4, 20, mw + 8, 22, 11);
        ctx.fill();
        const f = w.beast > 0 ? w.beast / w.beastMax : w.hype / 100;
        const hg = ctx.createLinearGradient(mx, 0, mx + mw, 0);
        hg.addColorStop(0, "#d42a2f");
        hg.addColorStop(1, w.beast > 0 ? "#ff6a3d" : "#f2c14e");
        ctx.fillStyle = hg;
        ctx.beginPath();
        ctx.roundRect(mx, 24, Math.max(0, mw * f), 14, 7);
        ctx.fill();
        ctx.textAlign = "center";
        ctx.font = "900 15px 'Saira Extra Condensed', Impact, sans-serif";
        ctx.fillStyle = w.beast > 0 ? "#fff1d6" : "#efe7d6";
        ctx.fillText(w.beast > 0 ? "BEAST MODE · 2X POINTS" : w.beastReady ? (Math.floor(w.t * 4) % 2 ? "HYPE FULL" : "TAP BEAST TO UNLEASH") : w.hype >= 80 ? "HYPE · CROWD'S GOING WILD" : "HYPE", W / 2, 37);
        const c = w.chase;
        if (c) {
          // the boss's stamina (drained by pins)
          ctx.fillStyle = "rgba(10,9,8,.75)";
          ctx.beginPath();
          ctx.roundRect(mx - 4, 48, mw + 8, 14, 7);
          ctx.fill();
          ctx.fillStyle = c.finisher ? (Math.floor(w.t * 6) % 2 ? "#f2c14e" : "#fff1d6") : "#c94bff";
          ctx.fillRect(mx, 51, (mw * (c.finisher ? 100 : c.stamina)) / 100, 8);
          ctx.font = "700 11px 'Chakra Petch', monospace";
          ctx.fillStyle = "rgba(242,225,182,.9)";
          ctx.fillText(
            c.finisher ? `${c.b.name.split(" ")[0].toUpperCase()} IS GASSED: FINISH THE GRIP` : `${c.b.name.split(" ")[0].toUpperCase()} · STAMINA`,
            W / 2,
            76,
          );
          if (c.warn > 0 && c.shown) {
            // the tell
            const mvd = MOVES[c.shown];
            const flash = Math.floor(w.t * 10) % 2;
            ctx.font = "900 34px 'Saira Extra Condensed', Impact, sans-serif";
            ctx.fillStyle = flash ? mvd.color : "#fff1d6";
            ctx.fillText(`⚠ ${c.b.name.split(" ")[0].toUpperCase()}'S ${mvd.name.toUpperCase()}`, W / 2, 214);
            ctx.font = "700 13px 'Chakra Petch', monospace";
            ctx.fillStyle = "#efe7d6";
            ctx.fillText(CHASE_TIP[c.shown] ?? "", W / 2, 234);
          }
        }
        if (w.beastReady) {
          ctx.strokeStyle = `rgba(255,106,61,${0.5 + Math.sin(w.t * 10) * 0.4})`;
          ctx.lineWidth = 3;
          ctx.beginPath();
          ctx.roundRect(mx - 6, 18, mw + 12, 26, 13);
          ctx.stroke();
        }
      }
      for (let i = 0; i < w.maxHearts; i++) {
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
      if (w.banner) {
        const a = Math.min(1, w.banner.life * 2, (3 - w.banner.life) * 4);
        ctx.globalAlpha = Math.max(0, a);
        ctx.fillStyle = "rgba(10,9,8,.78)";
        ctx.beginPath();
        ctx.roundRect(W / 2 - 300, 118, 600, 70, 14);
        ctx.fill();
        ctx.textAlign = "center";
        ctx.fillStyle = w.banner.c;
        ctx.font = "900 30px 'Saira Extra Condensed', Impact, sans-serif";
        ctx.fillText(w.banner.t, W / 2, 152);
        ctx.fillStyle = "#efe7d6";
        ctx.font = "600 16px 'Chakra Petch', monospace";
        ctx.fillText(w.banner.sub, W / 2, 176);
        ctx.globalAlpha = 1;
      }
      if (w.duel) drawDuel(w);
    };

    const loop = (now: number) => {
      const dt = Math.min(0.033, (now - lastT) / 1000);
      lastT = now;
      if (phaseRef.current === "play" && !world.current.over) {
        // Beast Mode: every point earned this frame counts double
        const w = world.current;
        const beastOn = w.beast > 0;
        const s0 = w.score;
        step(dt);
        if (beastOn && world.current === w && w.score > s0) w.score += w.score - s0;
      }
      {
        const w = world.current;
        const moving = phaseRef.current === "play" && !w.over && !w.duel;
        // the run-cycle video already carries each lion's effects; the live particles trail behind it
        stepFx(fx.current, skinRef.current, w.dist + PX, w.y + R, dt, moving, 0.6);
        // keep the Beast button in step (only re-render when it visibly changes)
        const ui = {
          on: phaseRef.current === "play" && w.level === 3 && !w.over,
          fill: Math.floor(w.hype / 10),
          ready: w.beastReady,
          active: w.beast > 0,
        };
        const key = `${ui.on}${ui.fill}${ui.ready}${ui.active}`;
        if (key !== beastUiKey.current) {
          beastUiKey.current = key;
          setBeastUi(ui);
        }
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
          <LevelPicker level={level} onPick={setLevel} best={best} best2={best2} best3={best3} />
          <div className="pinrun-btns">
            <button type="button" className="btn btn-primary">
              Start{level > 1 ? ` Lv.${level}` : ""}
            </button>
            <TempleButton onOpen={() => setTemple(true)} coins={wallet?.coins ?? 0} loggedIn={loggedIn} />
          </div>
          {level === 3 ? (
            <p className="pinrun-best">
              <b>Boss chase:</b> a Riser hunts you. Pins push them back. Tap <b>BEAST</b> when hype is full.
            </p>
          ) : null}
          {level === 2 && ABILITIES[skin] ? (
            <p className="pinrun-best">
              {skinById(skin)?.name}: <b>{ABILITIES[skin].name}</b> · {ABILITIES[skin].text}
            </p>
          ) : null}
        </div>
      ) : null}
      {phase === "over" ? (
        <div className="pinrun-overlay">
          <p className="eyebrow">Game over · Lv.{final.level} {LEVELS[final.level - 1].name}</p>
          <h2>{final.score.toLocaleString("en-AU")}</h2>
          <p className="pinrun-stats">
            {final.pins} pins · {final.coins} {final.coins === 1 ? "coin" : "coins"} grabbed
            {bestOf(final.level) ? ` · best ${bestOf(final.level)!.toLocaleString("en-AU")}` : ""}
          </p>
          <div className="pinrun-btns">
            <button type="button" className="btn btn-primary pinrun-again" onClick={start}>
              ↻ Run it back
            </button>
            <TempleButton onOpen={() => setTemple(true)} coins={wallet?.coins ?? 0} loggedIn={loggedIn} />
            <button type="button" className="btn btn-ghost pinrun-levels-btn" onClick={() => setPhase("title")}>
              Levels
            </button>
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
      {beastUi.on ? (
        <button
          type="button"
          className={`pinrun-beast${beastUi.ready ? " ready" : ""}${beastUi.active ? " active" : ""}`}
          style={{ "--fill": `${beastUi.active ? 100 : beastUi.fill * 10}%` } as React.CSSProperties}
          disabled={!beastUi.ready}
          // its own tap: don't let it count as a jump
          onPointerDown={(e) => {
            e.stopPropagation();
            e.preventDefault();
            unleash();
          }}
          aria-label={beastUi.ready ? "Unleash Beast Mode" : "Beast Mode (fill the hype meter)"}
        >
          <span aria-hidden>🔥</span> {beastUi.active ? "BEAST!" : "BEAST"}
        </button>
      ) : null}
      <button
        type="button"
        className="pinrun-mute"
        onClick={() => {
          const next = !muted;
          setMuted(next);
          mutedRef.current = next;
          if (next) stopRadio();
          else if (phase === "play") startRadio();
        }}
        aria-label={muted ? "Sound and radio on" : "Sound and radio off"}
        title={muted ? "Sound and radio on" : "Mute sound and radio"}
      >
        {muted ? "♪̸" : "♪"}
      </button>
      {temple ? <LionTemple wallet={wallet} loggedIn={loggedIn} onWallet={setWallet} onClose={() => setTemple(false)} /> : null}
    </div>
  );
}

/** Level select: Lion Temple, Crimson Peak and The Arena (all open to everyone). */
function LevelPicker({ level, onPick, best, best2, best3 }: { level: Lv; onPick: (l: Lv) => void; best: number | null; best2: number | null; best3: number | null }) {
  const stop = (e: React.PointerEvent | React.MouseEvent) => e.stopPropagation();
  const card = (n: Lv, img: string, name: string, sub: string) => (
    <button
      type="button"
      className={`lv-card${level === n ? " on" : ""}`}
      style={{ backgroundImage: `url(${img})` }}
      onPointerDown={stop}
      onClick={(e) => {
        stop(e);
        onPick(n);
      }}
      aria-pressed={level === n}
      aria-label={`Level ${n}: ${name}`}
    >
      <span className="lv-n">Lv.{n}</span>
      <b>{name}</b>
      <small>{sub}</small>
    </button>
  );
  const sub = (b: number | null, fresh: string) => (b ? `Best ${b.toLocaleString("en-AU")}` : fresh);
  return (
    <div className="lv-pick">
      {card(1, "/pinrun/l1-card.webp", "Lion Temple", sub(best, "Start here"))}
      {card(2, "/pinrun/l2-card.webp", "Crimson Peak", sub(best2, "Harder"))}
      {card(3, "/pinrun/l3-card.webp", "The Arena", sub(best3, "Boss chase"))}
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
                {ABILITIES[k.id] ? (
                  <p className="temple-ability">
                    <b>Lv.2+ ability · {ABILITIES[k.id].name}</b> {ABILITIES[k.id].text}
                  </p>
                ) : null}
                {ABILITIES3[k.id] ? (
                  <p className="temple-ability">
                    <b>Lv.3 ability · {ABILITIES3[k.id].name}</b> {ABILITIES3[k.id].text}
                  </p>
                ) : null}
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
