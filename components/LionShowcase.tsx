import Link from "next/link";
import { ANIM, DEFAULT_SKIN, skinById } from "@/lib/pinrun";

/** A member's equipped Pin Run lion, running with its effects (the same loop as the game). */
export function LionShowcase({ skin, title, mine = false, templeCoins }: { skin: string; title: string; mine?: boolean; templeCoins?: number }) {
  const k = skinById(skin) ?? skinById(DEFAULT_SKIN)!;
  return (
    <div className="panel lion-show">
      <h2 className="panel-title">
        {title}
        <small>
          <Link href="/play">{mine ? "Change →" : "Lion Temple →"}</Link>
        </small>
      </h2>
      <div className="lion-show-stage">
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
      <p className="lion-show-name">
        <b>{k.name}</b>
        <span>{k.blurb}</span>
      </p>
      {templeCoins !== undefined ? (
        <p className="lion-show-coins">
          <span className="coin" aria-hidden /> <b>{templeCoins.toLocaleString("en-AU")}</b> Temple coins
          <small>from coins you grab in Pin Run · spend them on lions</small>
        </p>
      ) : null}
    </div>
  );
}
