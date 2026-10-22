import Image from "next/image";

/**
 * The Lift: the club's pronation-lift artwork, shown as a dark ink silhouette that comes
 * to life in sections as a member earns Chalk: the plates first, then the body, the face,
 * and finally the lion, each spreading in ink blotches. At the target the whole piece is
 * lit and turns gold: lift complete. Masks are pre-rendered at 5% steps in /chalk/reveal.
 */
const STAGES = ["Plates", "Body", "Game face", "The lion", "Lift complete"];
const ART = "/chalk/lift.webp";

export function ChalkLift({ chalk, target, compact = false }: { chalk: number; target: number; compact?: boolean }) {
  const p = Math.max(0, Math.min(1, target > 0 ? chalk / target : 0));
  const done = p >= 1;
  const step = Math.min(19, Math.floor(p * 20));
  const mask = step > 0 && !done ? `url(/chalk/reveal/${String(step).padStart(2, "0")}.png)` : undefined;
  const stageIdx = done ? 4 : Math.min(3, Math.floor(p * 4));
  const sizes = compact ? "(max-width: 860px) 90vw, 360px" : "(max-width: 860px) 90vw, 520px";

  return (
    <figure className={`lift${done ? " lift-done" : ""}${compact ? " lift-compact" : ""}`}>
      <div className="lift-art" role="img" aria-label={`The Lift: ${chalk} of ${target} Chalk. ${STAGES[stageIdx]}.`}>
        <Image src={ART} alt="" fill sizes={sizes} className="lift-dim" />
        {step > 0 || done ? (
          <Image
            src={ART}
            alt=""
            fill
            sizes={sizes}
            className="lift-lit"
            style={mask ? { maskImage: mask, WebkitMaskImage: mask, maskSize: "100% 100%", WebkitMaskSize: "100% 100%" } : undefined}
          />
        ) : null}
        {done ? <div className="lift-stamp">Lift complete</div> : null}
      </div>
      <figcaption>
        <div className="lift-meta">
          <b>
            {chalk}
            <small>/{target} Chalk</small>
          </b>
          <span>{STAGES[stageIdx]}</span>
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
