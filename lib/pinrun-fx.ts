/**
 * Pin Run lion effects: each skin has a living aura and a particle emitter (petals, flames,
 * lightning, spray…) drawn on the game canvas. Particles live in world space, so they stream
 * off behind the lion as it runs. Everything here is cheap: plain shapes, capped counts.
 */

export type FxKind = "glow" | "petal" | "leaf" | "shard" | "flame" | "drop" | "puff" | "star" | "ember";

export interface Fx {
  k: FxKind;
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  max: number;
  size: number;
  rot: number;
  vr: number;
  c: string;
  /** Sway phase for drifting things (petals, leaves). */
  sw: number;
}

export interface Bolt {
  pts: [number, number][];
  life: number;
  c: string;
}

export interface FxState {
  parts: Fx[];
  bolts: Bolt[];
  acc: number;
  boltIn: number;
}

export const newFx = (): FxState => ({ parts: [], bolts: [], acc: 0, boltIn: 1 });

const MAX = 260;
const r = (a: number, b: number) => a + Math.random() * (b - a);
const pick = <T>(a: T[]) => a[Math.floor(Math.random() * a.length)];

/** Where the lion's body is, relative to its feet (x right, y up is negative). */
export const BODY = { x0: -48, x1: 52, y0: -92, y1: -18 };

interface Style {
  aura: [string, number]; // colour, strength 0-1
  rate: number; // particles per second
  spawn: (x: number, y: number, s: FxState, moving: boolean) => void;
}

const inBody = (x: number, y: number, fx = 0.5, fy = 0.5) => [
  x + BODY.x0 + (BODY.x1 - BODY.x0) * (fx + r(-0.35, 0.35)),
  y + BODY.y0 + (BODY.y1 - BODY.y0) * (fy + r(-0.35, 0.35)),
];

const add = (s: FxState, p: Partial<Fx> & Pick<Fx, "k" | "x" | "y">) => {
  if (s.parts.length >= MAX) return;
  const max = p.max ?? 1;
  s.parts.push({ vx: 0, vy: 0, size: 4, rot: r(0, 6.28), vr: 0, c: "#fff", sw: r(0, 6.28), life: max, max, ...p });
};

export const STYLES: Record<string, Style> = {
  stone: {
    aura: ["213,182,122", 0.22],
    rate: 14,
    spawn(x, y, s) {
      const [px, py] = inBody(x, y, 0.4, 0.9);
      add(s, { k: "glow", x: px, y: py, vx: r(-40, 10), vy: r(-50, -15), size: r(1.5, 3), c: "#f2e1b6", max: r(0.5, 0.9) });
      if (Math.random() < 0.15) {
        const [sx, sy] = inBody(x, y, 0.6, 0.3);
        add(s, { k: "star", x: sx, y: sy, size: r(4, 7), c: "#fff4cf", max: 0.35 });
      }
    },
  },
  sakura: {
    aura: ["243,170,200", 0.22],
    rate: 11,
    spawn(x, y, s) {
      const [px, py] = inBody(x, y, 0.35, 0.25);
      add(s, { k: "petal", x: px, y: py, vx: r(-90, -30), vy: r(-40, 20), size: r(4, 6.5), vr: r(-4, 4), c: pick(["#f7b6cc", "#ffd1df", "#f39ab8", "#fff0f5"]), max: r(1.4, 2.2) });
    },
  },
  jade: {
    aura: ["120,190,90", 0.22],
    rate: 12,
    spawn(x, y, s, moving) {
      add(s, { k: "puff", x: x + r(-40, -10), y: y - r(2, 14), vx: moving ? r(-70, -30) : r(-15, 15), vy: r(-25, -8), size: r(7, 12), c: pick(["#c9b25a", "#8fb46a", "#d8c37a"]), max: r(0.7, 1.1) });
      if (Math.random() < 0.4) {
        const [gx, gy] = inBody(x, y);
        add(s, { k: "glow", x: gx, y: gy, vy: r(-30, -10), size: r(1.5, 2.5), c: "#e8d48a", max: 0.7 });
      }
    },
  },
  wave: {
    aura: ["90,150,220", 0.22],
    rate: 30,
    spawn(x, y, s, moving) {
      const front = Math.random() < 0.5;
      add(s, {
        k: "drop",
        x: x + (front ? r(10, 40) : r(-45, -15)),
        y: y - r(0, 6),
        vx: moving ? r(-160, -40) : r(-40, 40),
        vy: r(-260, -120),
        size: r(1.8, 3.2),
        c: pick(["#cfe8ff", "#9ec4e8", "#ffffff", "#5f8fd0"]),
        max: r(0.5, 0.8),
      });
      if (Math.random() < 0.25) add(s, { k: "puff", x: x + r(-40, 30), y: y - 2, vx: r(-60, -10), vy: r(-10, 0), size: r(5, 9), c: "#e8f4ff", max: 0.5 });
    },
  },
  crystal: {
    aura: ["120,210,255", 0.28],
    rate: 13,
    spawn(x, y, s) {
      const [px, py] = inBody(x, y, 0.3, 0.4);
      add(s, { k: "shard", x: px, y: py, vx: r(-80, -20), vy: r(-60, 20), size: r(3, 6), vr: r(-6, 6), c: pick(["#9fe0ff", "#d8f4ff", "#5fb8f0"]), max: r(0.7, 1.2) });
      if (Math.random() < 0.5) {
        const [sx, sy] = inBody(x, y);
        add(s, { k: "star", x: sx, y: sy, size: r(4, 8), c: "#e6f8ff", max: 0.3 });
      }
    },
  },
  flame: {
    aura: ["255,110,50", 0.38],
    rate: 48,
    spawn(x, y, s, moving) {
      const [px, py] = inBody(x, y, 0.45, 0.6);
      add(s, { k: "flame", x: px, y: py, vx: moving ? r(-50, -10) : r(-10, 10), vy: r(-130, -70), size: r(5, 9), c: pick(["#ffb347", "#ff7a2f", "#ff4a2a"]), max: r(0.25, 0.42) });
      if (Math.random() < 0.2) add(s, { k: "ember", x: px, y: py, vx: r(-60, 20), vy: r(-160, -80), size: r(1.2, 2.2), c: "#ffd27a", max: r(0.6, 1) });
    },
  },
  thunder: {
    aura: ["255,210,90", 0.26],
    rate: 16,
    spawn(x, y, s) {
      const [px, py] = inBody(x, y);
      add(s, { k: "glow", x: px, y: py, vx: r(-160, 60), vy: r(-120, 60), size: r(1.2, 2.4), c: "#ffe9a0", max: r(0.2, 0.4) });
      if (Math.random() < 0.15) add(s, { k: "puff", x: x + r(-50, -10), y: y + BODY.y0 + r(-10, 10), vx: r(-50, -20), vy: r(-6, 6), size: r(12, 18), c: "#8a8580", max: 0.9 });
    },
  },
  moon: {
    aura: ["170,120,255", 0.32],
    rate: 14,
    spawn(x, y, s, moving) {
      add(s, { k: "puff", x: x + r(-45, 20), y: y - r(0, 18), vx: moving ? r(-60, -20) : r(-10, 10), vy: r(-20, -5), size: r(8, 13), c: pick(["#7a55c8", "#9a7ae0", "#5a3c9a"]), max: r(0.8, 1.2) });
      if (Math.random() < 0.6) {
        const [sx, sy] = [x + r(-70, 60), y + r(-120, -20)];
        add(s, { k: "star", x: sx, y: sy, size: r(3, 6), c: "#e8dcff", max: r(0.4, 0.8) });
      }
    },
  },
  eclipse: {
    aura: ["255,120,60", 0.3],
    rate: 22,
    spawn(x, y, s) {
      const [px, py] = inBody(x, y, 0.5, 0.5);
      add(s, { k: "ember", x: px, y: py, vx: r(-70, 10), vy: r(-130, -50), size: r(1.2, 2.4), c: pick(["#ffb06a", "#ff6a3a", "#ffd27a"]), max: r(0.6, 1.1) });
      if (Math.random() < 0.18) {
        const [lx, ly] = inBody(x, y, 0.4, 0.2);
        add(s, { k: "leaf", x: lx, y: ly, vx: r(-80, -30), vy: r(-30, 10), size: r(5, 7), vr: r(-3, 3), c: pick(["#d8391f", "#ff5a2a", "#b8261a"]), max: r(1.4, 2) });
      }
    },
  },
};

/** Spawns and moves particles. (x, y) is the lion's feet in world space. */
export function stepFx(s: FxState, skin: string, x: number, y: number, dt: number, moving: boolean) {
  const st = STYLES[skin] ?? STYLES.stone;
  s.acc += st.rate * dt;
  while (s.acc >= 1) {
    s.acc -= 1;
    st.spawn(x, y, s, moving);
  }
  if (skin === "thunder") {
    s.boltIn -= dt;
    if (s.boltIn <= 0) {
      s.boltIn = r(0.5, 1.3);
      // a jagged bolt from above the mane down past the body, with a fork
      const sx = x + r(-50, 40);
      let px = sx;
      let py = y - r(120, 150);
      const pts: [number, number][] = [[px, py]];
      while (py < y - 10) {
        px += r(-14, 14);
        py += r(10, 18);
        pts.push([px, py]);
      }
      s.bolts.push({ pts, life: 0.18, c: "#ffe9a0" });
      for (let i = 0; i < 8; i++) add(s, { k: "glow", x: px, y: py, vx: r(-120, 120), vy: r(-160, 0), size: r(1.5, 2.5), c: "#fff4c0", max: 0.35 });
    }
  }
  for (const p of s.parts) {
    p.life -= dt;
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.rot += p.vr * dt;
    p.sw += dt * 3;
    if (p.k === "petal" || p.k === "leaf") {
      p.vy += 60 * dt;
      p.x += Math.sin(p.sw) * 18 * dt;
    } else if (p.k === "drop" || p.k === "shard") p.vy += 900 * dt;
    else if (p.k === "flame") p.size *= 1 - dt * 2.4;
    else if (p.k === "puff") p.size += dt * 10;
  }
  s.parts = s.parts.filter((p) => p.life > 0);
  for (const b of s.bolts) b.life -= dt;
  s.bolts = s.bolts.filter((b) => b.life > 0);
}

/** The glow behind the lion. Drawn before the lion, in screen space (feet at fx, fy). */
export function drawAura(ctx: CanvasRenderingContext2D, skin: string, fx: number, fy: number, t: number) {
  const [rgb, k] = (STYLES[skin] ?? STYLES.stone).aura;
  const cx = fx + (BODY.x0 + BODY.x1) / 2;
  const cy = fy + (BODY.y0 + BODY.y1) / 2;
  const pulse = 0.85 + Math.sin(t * 3) * 0.15;
  const rad = 78 * pulse;
  ctx.save();
  ctx.globalCompositeOperation = "lighter";
  const g = ctx.createRadialGradient(cx, cy, 6, cx, cy, rad);
  g.addColorStop(0, `rgba(${rgb},${0.55 * k})`);
  g.addColorStop(0.55, `rgba(${rgb},${0.22 * k})`);
  g.addColorStop(1, `rgba(${rgb},0)`);
  ctx.fillStyle = g;
  ctx.beginPath();
  ctx.arc(cx, cy, rad, 0, Math.PI * 2);
  ctx.fill();
  if (skin === "eclipse" || skin === "moon") {
    // the moon / eclipse ring hanging behind the mane
    const mx = fx + 18;
    const my = fy - 92;
    const rr = 30 + Math.sin(t * 2) * 1.5;
    ctx.strokeStyle = skin === "eclipse" ? `rgba(255,150,70,${0.55 + Math.sin(t * 5) * 0.15})` : "rgba(205,180,255,.45)";
    ctx.lineWidth = skin === "eclipse" ? 3 : 2;
    ctx.shadowColor = skin === "eclipse" ? "#ff7a3a" : "#b994ff";
    ctx.shadowBlur = 16;
    ctx.beginPath();
    ctx.arc(mx, my, rr, 0, Math.PI * 2);
    ctx.stroke();
  }
  ctx.restore();
}

/** Particles and bolts, in world space minus the camera. */
const BACK = new Set<FxKind>(["puff", "drop"]);

export function drawFx(ctx: CanvasRenderingContext2D, s: FxState, cam: number, layer: "back" | "front") {
  ctx.save();
  for (const p of s.parts) {
    if (BACK.has(p.k) !== (layer === "back")) continue;
    const a = Math.max(0, Math.min(1, p.life / p.max));
    const x = p.x - cam;
    const y = p.y;
    const additive = p.k === "glow" || p.k === "flame" || p.k === "ember" || p.k === "star";
    ctx.globalCompositeOperation = additive ? "lighter" : "source-over";
    ctx.globalAlpha = p.k === "puff" ? a * 0.5 : p.k === "petal" || p.k === "leaf" ? Math.min(1, a * 1.6) : a;
    ctx.fillStyle = p.c;
    switch (p.k) {
      case "glow":
      case "ember": {
        ctx.beginPath();
        ctx.arc(x, y, p.size * (p.k === "ember" ? 1 : 1.4), 0, Math.PI * 2);
        ctx.fill();
        break;
      }
      case "star": {
        const z = p.size * (0.4 + a * 0.6);
        ctx.fillRect(x - z, y - 0.8, z * 2, 1.6);
        ctx.fillRect(x - 0.8, y - z, 1.6, z * 2);
        break;
      }
      case "flame": {
        const g = ctx.createRadialGradient(x, y, 0, x, y, p.size);
        g.addColorStop(0, "rgba(255,240,180,.9)");
        g.addColorStop(0.4, p.c);
        g.addColorStop(1, "rgba(255,60,20,0)");
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.ellipse(x, y, p.size * 0.7, p.size * 1.15, 0, 0, Math.PI * 2);
        ctx.fill();
        break;
      }
      case "petal": {
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(p.rot);
        ctx.beginPath();
        ctx.ellipse(0, 0, p.size, p.size * 0.55 * Math.abs(Math.cos(p.sw)) + 0.6, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
        break;
      }
      case "leaf": {
        // a little five-point maple leaf
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(p.rot);
        ctx.beginPath();
        for (let i = 0; i < 10; i++) {
          const ang = (i / 10) * Math.PI * 2 - Math.PI / 2;
          const rr = i % 2 ? p.size * 0.45 : p.size;
          ctx.lineTo(Math.cos(ang) * rr, Math.sin(ang) * rr);
        }
        ctx.fill();
        ctx.restore();
        break;
      }
      case "shard": {
        ctx.save();
        ctx.translate(x, y);
        ctx.rotate(p.rot);
        ctx.beginPath();
        ctx.moveTo(0, -p.size);
        ctx.lineTo(p.size * 0.4, 0);
        ctx.lineTo(0, p.size);
        ctx.lineTo(-p.size * 0.4, 0);
        ctx.closePath();
        ctx.fill();
        ctx.restore();
        break;
      }
      case "drop": {
        ctx.beginPath();
        ctx.arc(x, y, p.size, 0, Math.PI * 2);
        ctx.fill();
        break;
      }
      case "puff": {
        // soft-edged cloud: solid centre fading out
        const g = ctx.createRadialGradient(x, y, 0, x, y, p.size);
        g.addColorStop(0, p.c);
        g.addColorStop(1, "rgba(0,0,0,0)");
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(x, y, p.size, 0, Math.PI * 2);
        ctx.fill();
        break;
      }
    }
  }
  ctx.globalAlpha = 1;
  ctx.globalCompositeOperation = "lighter";
  for (const b of layer === "front" ? s.bolts : []) {
    ctx.strokeStyle = b.c;
    ctx.shadowColor = "#ffe9a0";
    ctx.shadowBlur = 14;
    ctx.globalAlpha = Math.min(1, b.life / 0.1);
    ctx.lineWidth = 2.2;
    ctx.beginPath();
    b.pts.forEach(([x, y], i) => (i ? ctx.lineTo(x - cam, y) : ctx.moveTo(x - cam, y)));
    ctx.stroke();
  }
  ctx.restore();
}
