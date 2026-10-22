"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";

const HIDE_KEY = "88r-merch-lion-hidden";
const LINES = ["Fresh gear from the den.", "Rep the table. See the merch.", "The lion approves this drip."];

/**
 * A lion-head badge in the corner that nudges visitors to the shop. It peeks in after a short
 * delay (longer on the homepage, so it doesn't fight the hero lion intro), shows a speech
 * bubble, and can be dismissed. Hidden on the shop itself and in the admin.
 */
export function MerchLion() {
  const path = usePathname();
  const [show, setShow] = useState(false);
  const [talk, setTalk] = useState(false);
  const [line, setLine] = useState(LINES[0]);

  const off = path.startsWith("/shop") || path.startsWith("/admin");

  useEffect(() => {
    if (off) return;
    let hidden = false;
    try {
      hidden = sessionStorage.getItem(HIDE_KEY) === "1";
    } catch {}
    if (hidden) return;
    setLine(LINES[Math.floor(Math.random() * LINES.length)]);
    const wait = path === "/" ? 7000 : 2500;
    const t1 = setTimeout(() => setShow(true), wait);
    const t2 = setTimeout(() => setTalk(true), wait + 700);
    const t3 = setTimeout(() => setTalk(false), wait + 7700);
    return () => [t1, t2, t3].forEach(clearTimeout);
  }, [path, off]);

  if (off || !show) return null;

  const dismiss = () => {
    setShow(false);
    try {
      sessionStorage.setItem(HIDE_KEY, "1");
    } catch {}
  };

  return (
    <div className="merch-lion" onMouseEnter={() => setTalk(true)} onMouseLeave={() => setTalk(false)}>
      <div className={`merch-bubble${talk ? " on" : ""}`} role="status">
        <b>{line}</b>
        <span>Club tees, comp jerseys &amp; grip gear</span>
        <Link href="/shop" className="merch-go">
          Visit the shop →
        </Link>
      </div>
      <Link href="/shop" className="merch-badge" aria-label="Check out 88 Risers club merch in the shop">
        <span className="merch-face" aria-hidden />
        <span className="merch-tag" aria-hidden>
          MERCH
        </span>
      </Link>
      <button type="button" className="merch-x" onClick={dismiss} aria-label="Hide the merch lion">
        ×
      </button>
    </div>
  );
}
