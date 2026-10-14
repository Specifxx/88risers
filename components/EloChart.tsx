"use client";

import { useState } from "react";

export interface EloPoint {
  elo: number;
  label: string;
  date: string;
}

const W = 640;
const H = 200;
const PAD = { t: 16, r: 12, b: 26, l: 40 };

/** Elo over time: one series, thin line, crosshair + tooltip on hover. */
export function EloChart({ points }: { points: EloPoint[] }) {
  const [hover, setHover] = useState<number | null>(null);
  if (points.length < 2) return null;

  const elos = points.map((p) => p.elo);
  const lo = Math.floor((Math.min(...elos) - 15) / 25) * 25;
  const hi = Math.ceil((Math.max(...elos) + 15) / 25) * 25;
  const x = (i: number) => PAD.l + (i / (points.length - 1)) * (W - PAD.l - PAD.r);
  const y = (v: number) => PAD.t + (1 - (v - lo) / (hi - lo)) * (H - PAD.t - PAD.b);
  const path = points.map((p, i) => `${i ? "L" : "M"}${x(i).toFixed(1)},${y(p.elo).toFixed(1)}`).join("");
  const area = `${path}L${x(points.length - 1)},${H - PAD.b}L${x(0)},${H - PAD.b}Z`;
  const ticks = [lo, Math.round((lo + hi) / 2), hi];

  function onMove(e: React.PointerEvent<SVGSVGElement>) {
    const r = e.currentTarget.getBoundingClientRect();
    const px = ((e.clientX - r.left) / r.width) * W;
    const i = Math.round(((px - PAD.l) / (W - PAD.l - PAD.r)) * (points.length - 1));
    setHover(Math.max(0, Math.min(points.length - 1, i)));
  }

  const h = hover !== null ? points[hover] : null;

  return (
    <div className="chart">
      <svg
        viewBox={`0 0 ${W} ${H}`}
        role="img"
        aria-label={`Elo rating over ${points.length - 1} matches, from ${points[0].elo} to ${points.at(-1)!.elo}`}
        onPointerMove={onMove}
        onPointerLeave={() => setHover(null)}
      >
        <defs>
          <linearGradient id="elo-fill" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0" stopColor="#d5b67a" stopOpacity="0.22" />
            <stop offset="1" stopColor="#d5b67a" stopOpacity="0" />
          </linearGradient>
        </defs>
        {ticks.map((t) => (
          <g key={t}>
            <line x1={PAD.l} x2={W - PAD.r} y1={y(t)} y2={y(t)} stroke="rgba(213,182,122,0.12)" />
            <text x={PAD.l - 8} y={y(t) + 4} textAnchor="end" fontSize="11" fill="#6f6858" fontFamily="var(--f-tech)">
              {t}
            </text>
          </g>
        ))}
        <path d={area} fill="url(#elo-fill)" />
        <path d={path} fill="none" stroke="#d5b67a" strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" />
        <circle cx={x(points.length - 1)} cy={y(points.at(-1)!.elo)} r="4.5" fill="#f2e1b6" stroke="#100e0b" strokeWidth="2" />
        <text x={PAD.l} y={H - 6} fontSize="11" fill="#6f6858" fontFamily="var(--f-tech)">
          {points[0].date}
        </text>
        <text x={W - PAD.r} y={H - 6} fontSize="11" fill="#6f6858" textAnchor="end" fontFamily="var(--f-tech)">
          {points.at(-1)!.date}
        </text>
        {h && hover !== null ? (
          <g pointerEvents="none">
            <line x1={x(hover)} x2={x(hover)} y1={PAD.t} y2={H - PAD.b} stroke="rgba(242,225,182,0.35)" />
            <circle cx={x(hover)} cy={y(h.elo)} r="5" fill="#f2e1b6" stroke="#100e0b" strokeWidth="2" />
          </g>
        ) : null}
        <rect x={PAD.l} y={0} width={W - PAD.l - PAD.r} height={H} fill="transparent" />
      </svg>
      {h && hover !== null ? (
        <div className="chart-tip" style={{ left: `${(x(hover) / W) * 100}%`, top: `${(y(h.elo) / H) * 100}%` }}>
          <b>{h.elo}</b>
          {h.label} · {h.date}
        </div>
      ) : null}
    </div>
  );
}
