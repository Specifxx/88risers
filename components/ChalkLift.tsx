/**
 * The Lift: a cartoon puller doing a rising/pronation lift that progresses with
 * season Chalk. Plates are added as you go, the stack leaves the floor at the halfway
 * mark, the wrist turns over, and at the target it locks out with an "UP!".
 * An abstract cartoon nod to the classic pronation-lift videos: big build, green tee.
 */
const STAGES = ["Chalked up", "Strapped in", "Off the floor", "Full pronation", "Lift complete"];

const SKIN = "#efc39b";
const INK = "#16110d";

/** A cartoon limb: a thick rounded stroke with an ink outline underneath. */
function Limb({ x1, y1, x2, y2, w, color = SKIN }: { x1: number; y1: number; x2: number; y2: number; w: number; color?: string }) {
  return (
    <>
      <line x1={x1} y1={y1} x2={x2} y2={y2} stroke={INK} strokeWidth={w + 6} strokeLinecap="round" />
      <line x1={x1} y1={y1} x2={x2} y2={y2} stroke={color} strokeWidth={w} strokeLinecap="round" />
    </>
  );
}

export function ChalkLift({ chalk, target, compact = false }: { chalk: number; target: number; compact?: boolean }) {
  const p = Math.max(0, Math.min(1, target > 0 ? chalk / target : 0));
  const done = p >= 1;
  const stage = done ? 4 : Math.min(3, Math.floor(p * 4));

  const floor = 318;
  const lift = p < 0.5 ? 0 : ((p - 0.5) / 0.5) * 34; // how far the stack is off the floor
  const turn = -42 * p; // wrist pronation, degrees
  const plates = done ? 5 : stage + 2;
  const gx = 171; // grip centre
  const gy = 238 - lift;
  const plateTop = floor - lift - plates * 11;
  const elbow = { x: 78, y: 198 };
  const wrist = { x: gx - 16, y: gy - 2 };
  // point a fraction of the way along the forearm (for the wrist tape and veins)
  const along = (t: number) => ({ x: elbow.x + (wrist.x - elbow.x) * t, y: elbow.y + (wrist.y - elbow.y) * t });
  const tape0 = along(0.78);
  const tape1 = along(0.97);

  return (
    <figure className={`lift${done ? " lift-done" : ""}${compact ? " lift-compact" : ""}`}>
      <svg viewBox="20 22 270 306" role="img" aria-label={`The Lift: ${chalk} of ${target} Chalk. ${STAGES[stage]}.`}>
        <defs>
          <filter id="lift-glow" x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur stdDeviation="6" result="b" />
            <feMerge>
              <feMergeNode in="b" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
          <linearGradient id="lift-tee" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor="#2fbfae" />
            <stop offset="1" stopColor="#178a7e" />
          </linearGradient>
        </defs>

        {/* floor */}
        <ellipse cx="150" cy={floor + 2} rx="128" ry="9" className="lift-shadow" />

        <g filter={done ? "url(#lift-glow)" : undefined}>
          {/* back arm: hand resting on the knee */}
          <Limb x1={200} y1={122} x2={216} y2={186} w={32} />
          <Limb x1={216} y1={186} x2={230} y2={220} w={28} />
          <circle cx="233" cy="225" r="14" fill={SKIN} stroke={INK} strokeWidth="3" />

          {/* legs: deep squat, knees out */}
          <Limb x1={54} y1={238} x2={64} y2={304} w={26} />
          <Limb x1={234} y1={232} x2={226} y2={304} w={26} />
          <ellipse cx="62" cy="311" rx="20" ry="8" fill={SKIN} stroke={INK} strokeWidth="3" />
          <ellipse cx="232" cy="311" rx="20" ry="8" fill={SKIN} stroke={INK} strokeWidth="3" />
          <Limb x1={116} y1={212} x2={54} y2={236} w={36} />
          <Limb x1={178} y1={212} x2={234} y2={230} w={36} />
          {/* shorts */}
          <path d="M90,188 L198,190 L220,226 L180,238 L148,220 L116,240 L70,232 Z" fill="#151210" stroke={INK} strokeWidth="3" strokeLinejoin="round" />

          {/* torso in the club tee */}
          <path d="M74,114 C66,150 80,184 92,202 L200,204 C214,180 218,148 208,114 C180,94 104,94 74,114 Z" fill="url(#lift-tee)" stroke={INK} strokeWidth="3" />
          {/* abstract chest print */}
          <g className="lift-print">
            <circle cx="128" cy="150" r="9" />
            <circle cx="150" cy="144" r="7" />
            <circle cx="160" cy="162" r="9" />
            <circle cx="136" cy="170" r="7" />
            <circle cx="146" cy="157" r="4" />
          </g>

          {/* head */}
          <rect x="129" y="90" width="24" height="16" fill={SKIN} stroke={INK} strokeWidth="3" />
          <circle cx="141" cy="74" r="25" fill={SKIN} stroke={INK} strokeWidth="3" />
          <circle cx="116" cy="77" r="6" fill={SKIN} stroke={INK} strokeWidth="3" />
          <g className="lift-hair">
            <circle cx="122" cy="62" r="9" />
            <circle cx="132" cy="52" r="10" />
            <circle cx="146" cy="49" r="10" />
            <circle cx="159" cy="55" r="9" />
            <circle cx="166" cy="66" r="7" />
            <circle cx="117" cy="72" r="6" />
          </g>
          <path d="M127,76 l9,3 M156,76 l-9,3" className="lift-brow" />
          <path d="M131,83 h6 M147,83 h6" className="lift-eye" />
          <rect x="134" y="92" width="15" height="6" rx="2" className="lift-teeth" />
          <path d="M117,82 q2,24 24,27 q22,-3 24,-27 q-8,12 -24,13 q-16,-1 -24,-13 Z" className="lift-beard" />
          {stage >= 3 ? (
            <g className="lift-sweat">
              <path d="M170,58 q4,6 0,9 q-4,-3 0,-9 Z" />
              <path d="M110,56 q3,5 0,8 q-3,-3 0,-8 Z" />
            </g>
          ) : null}

          {/* sleeves */}
          <path d="M72,116 C64,130 64,144 70,152 L100,146 L98,110 Z" fill="url(#lift-tee)" stroke={INK} strokeWidth="3" strokeLinejoin="round" />
          <path d="M208,116 C218,128 220,142 214,150 L188,144 L190,110 Z" fill="url(#lift-tee)" stroke={INK} strokeWidth="3" strokeLinejoin="round" />

          {/* plates + loading pin + strap */}
          {Array.from({ length: plates }, (_, i) => {
            const y = floor - lift - (i + 1) * 11;
            return (
              <g key={i}>
                <rect x="122" y={y} width="98" height="11" rx="2" className={i % 2 ? "lift-plate alt" : "lift-plate"} />
                <line x1="124" y1={y + 2.5} x2="218" y2={y + 2.5} className="lift-plate-hi" />
              </g>
            );
          })}
          <rect x={gx - 5} y={plateTop - 12} width="10" height="12" rx="2" className="lift-pin" />
          <line x1={gx} y1={plateTop - 12} x2={gx} y2={gy + 10} className="lift-strap" />
          {lift > 0 ? (
            <g className="lift-motion">
              <path d={`M128,${floor - 2} h18 M160,${floor - 4} h22 M196,${floor - 2} h16`} />
            </g>
          ) : null}

          {/* lifting arm: elbow braced on the thigh */}
          <Limb x1={84} y1={126} x2={elbow.x} y2={elbow.y} w={34} />
          <Limb x1={elbow.x} y1={elbow.y} x2={wrist.x} y2={wrist.y} w={34} />
          {stage >= 1 ? <line x1={tape0.x} y1={tape0.y} x2={tape1.x} y2={tape1.y} className="lift-tape" /> : null}
          {stage >= 3 ? (
            <g className="lift-veins">
              <path d={`M${along(0.2).x},${along(0.2).y - 4} q12,-6 24,0 q12,5 22,-2`} />
              <path d={`M${along(0.45).x},${along(0.45).y + 3} q10,4 20,0`} />
            </g>
          ) : null}

          {/* fist on the handle, turning over as Chalk builds */}
          <g transform={`translate(${gx} ${gy}) rotate(${turn})`}>
            <rect x="-4" y="-26" width="8" height="14" rx="3" className="lift-handle" />
            <rect x="-17" y="-15" width="34" height="30" rx="11" fill={SKIN} stroke={INK} strokeWidth="3" />
            <path d="M-6,-14 v10 M4,-14 v10 M13,-12 v8" className="lift-knuckles" />
            <path d="M-17,2 q10,6 20,0" className="lift-knuckles" />
          </g>
          {chalk > 0 ? (
            <g className="lift-dust">
              <circle cx={gx + 22} cy={gy - 20} r="2.4" />
              <circle cx={gx + 30} cy={gy - 10} r="1.7" />
              <circle cx={gx + 16} cy={gy - 30} r="1.5" />
              <circle cx={gx - 22} cy={gy - 26} r="1.4" />
            </g>
          ) : null}
        </g>

        {done ? (
          <g className="lift-up">
            <path d="M226,38 l12,14 l17,-8 l-3,18 l18,6 l-16,10 l8,16 l-18,-3 l-6,17 l-10,-15 l-16,9 l2,-18 l-17,-6 l16,-9 l-7,-17 l18,4 Z" />
            <text x="236" y="80" textAnchor="middle">
              UP!
            </text>
          </g>
        ) : null}
      </svg>
      <figcaption>
        <div className="lift-meta">
          <b>
            {chalk}
            <small>/{target} Chalk</small>
          </b>
          <span>{STAGES[stage]}</span>
        </div>
        <div className="lift-bar" aria-hidden>
          <span style={{ width: `${p * 100}%` }} />
          {[25, 50, 75].map((t) => (
            <i key={t} style={{ left: `${t}%` }} className={p * 100 >= t ? "hit" : undefined} />
          ))}
        </div>
      </figcaption>
    </figure>
  );
}
