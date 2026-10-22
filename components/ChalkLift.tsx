import Image from "next/image";

/**
 * The Lift: the club's pronation-lift artwork, shown as a dark ink silhouette that lights
 * up in full colour from the floor upward as a member earns Chalk. At the target the whole
 * piece is lit and turns gold: lift complete.
 */
const STAGES = ["Chalked up", "Strapped in", "Off the floor", "Full pronation", "Lift complete"];
const ART = "/chalk/lift.webp";

export function ChalkLift({ chalk, target, compact = false }: { chalk: number; target: number; compact?: boolean }) {
  const p = Math.max(0, Math.min(1, target > 0 ? chalk / target : 0));
  const done = p >= 1;
  const stage = done ? 4 : Math.min(3, Math.floor(p * 4));
  const top = `${((1 - p) * 100).toFixed(2)}%`;
  const sizes = compact ? "(max-width: 860px) 90vw, 360px" : "(max-width: 860px) 90vw, 520px";

  return (
    <figure className={`lift${done ? " lift-done" : ""}${compact ? " lift-compact" : ""}`}>
      <div className="lift-art" role="img" aria-label={`The Lift: ${chalk} of ${target} Chalk. ${STAGES[stage]}.`}>
        <Image src={ART} alt="" fill sizes={sizes} className="lift-dim" />
        <Image src={ART} alt="" fill sizes={sizes} className="lift-lit" style={{ clipPath: `inset(${top} 0 0 0)` }} />
        {p > 0 && !done ? (
          <div className="lift-line" style={{ top }}>
            <span>{chalk}</span>
          </div>
        ) : null}
        {done ? <div className="lift-stamp">Lift complete</div> : null}
      </div>
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
