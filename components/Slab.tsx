"use client";

import Link from "next/link";
import { useRef } from "react";

interface Props {
  label: { name: string; sub?: string | null; grade: string; gradeLabel?: string };
  href?: string;
  className?: string;
  children: React.ReactNode;
  /** Max tilt in degrees. */
  tilt?: number;
}

/**
 * A graded-card "slab": acrylic case, printed label, holographic glare that
 * follows the pointer. Mirrors the cased champion cards winners take home.
 */
export function Slab({ label, href, className = "", children, tilt = 12 }: Props) {
  const ref = useRef<HTMLDivElement>(null);
  const frame = useRef(0);

  function onMove(e: React.PointerEvent) {
    const el = ref.current;
    if (!el || e.pointerType === "touch") return;
    const r = el.getBoundingClientRect();
    const x = (e.clientX - r.left) / r.width;
    const y = (e.clientY - r.top) / r.height;
    cancelAnimationFrame(frame.current);
    frame.current = requestAnimationFrame(() => {
      el.style.setProperty("--ry", `${(x - 0.5) * tilt}deg`);
      el.style.setProperty("--rx", `${(0.5 - y) * tilt}deg`);
      el.style.setProperty("--mx", `${x * 100}%`);
      el.style.setProperty("--my", `${y * 100}%`);
      el.style.setProperty("--glare", "1");
    });
    el.classList.add("is-active");
  }

  function onLeave() {
    const el = ref.current;
    if (!el) return;
    cancelAnimationFrame(frame.current);
    el.classList.remove("is-active");
    el.style.setProperty("--rx", "0deg");
    el.style.setProperty("--ry", "0deg");
    el.style.setProperty("--glare", "0");
  }

  const inner = (
    <div className="slab-case">
      <div className="slab-label">
        <div style={{ minWidth: 0 }}>
          <div className="l-name">{label.name}</div>
          {label.sub ? <span className="l-sub">{label.sub}</span> : null}
        </div>
        <div className="l-grade">
          <small>{label.gradeLabel ?? "RISER ID"}</small>
          {label.grade}
        </div>
      </div>
      <div className="slab-window">{children}</div>
    </div>
  );

  return (
    <div ref={ref} className={`slab ${className}`} onPointerMove={onMove} onPointerLeave={onLeave}>
      {href ? (
        <Link href={href} style={{ display: "block", textDecoration: "none", color: "inherit" }}>
          {inner}
        </Link>
      ) : (
        inner
      )}
    </div>
  );
}
