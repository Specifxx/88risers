import Image from "next/image";
import type { Style } from "@/lib/coins";

/** The member's coin card: name, title, balance, and whatever frame/badge they've unlocked. */
export function RiserPass({
  name,
  handle,
  coins,
  style,
  record,
}: {
  name: string;
  handle: string;
  coins: number;
  style: Style;
  /** Supermatch prediction record, e.g. "3/4 · 75%". */
  record?: string | null;
}) {
  return (
    <div className={`pass${style.frame ? ` pass-${style.frame}` : ""}`}>
      <div className="pass-inner">
        <div className="pass-top">
          <Image src="/crest.jpg" alt="" width={44} height={44} className="pass-crest" />
          <span>88 RISERS · MEMBER PASS</span>
        </div>
        {style.badge ? <span className="pass-lion" aria-label="Lion badge" /> : null}
        <p className="pass-name">{name}</p>
        <p className="pass-handle">@{handle}</p>
        {style.title ? <p className="pass-title">{style.title}</p> : null}
        <div className="pass-coins">
          <span className="coin" aria-hidden />
          <b>{coins.toLocaleString("en-AU")}</b>
          <small>coins</small>
        </div>
        <p className="pass-record">
          <span>Supermatch picks</span> <b>{record ?? "No results yet"}</b>
        </p>
      </div>
    </div>
  );
}
