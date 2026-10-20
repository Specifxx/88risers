"use client";

import { useEffect, useRef, useState } from "react";

const SEEN_KEY = "88r-lion-intro";

/**
 * The lion mascot behind the hero card. On the first homepage visit of a session it leaps
 * out, strikes at the viewer and settles back behind the card; afterwards it just rests there.
 */
export function HeroLion() {
  const [mode, setMode] = useState<"intro" | "rest" | null>(null);
  const decided = useRef(false);

  useEffect(() => {
    if (decided.current) return; // effects run twice in dev
    decided.current = true;
    let seen = false;
    try {
      seen = sessionStorage.getItem(SEEN_KEY) === "1";
      sessionStorage.setItem(SEEN_KEY, "1");
    } catch {
      // storage blocked: play the intro
    }
    const calm = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    setMode(seen || calm ? "rest" : "intro");
  }, []);

  if (!mode) return null;
  return (
    <>
      <div className={`hero-lion ${mode}`} aria-hidden />
      {mode === "intro" ? (
        <div className="hero-claw" aria-hidden>
          <span />
          <span />
          <span />
        </div>
      ) : null}
    </>
  );
}
