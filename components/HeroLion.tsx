"use client";

import { useEffect, useRef, useState } from "react";

const SEEN_KEY = "88r-lion-intro";

/**
 * The lion mascot behind the hero card. On the first homepage visit of a session the lion
 * (a video) pounces out from behind the card, roars at the viewer and slinks back, where the
 * resting head fades in; afterwards only the resting head shows.
 */
export function HeroLion() {
  const [mode, setMode] = useState<"intro" | "rest" | null>(null);
  const decided = useRef(false);
  const video = useRef<HTMLVideoElement>(null);

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

  // Play the pounce once enough of it has loaded; if it can't load or play in time, just rest.
  useEffect(() => {
    const v = video.current;
    if (mode !== "intro" || !v) return;
    const card = v.parentElement;
    let started = false;
    let ready = v.readyState >= 4; // enough buffered to play through
    let seen = false; // card is on screen
    const giveUp = () => !started && setMode("rest");
    // Too slow to load: skip. (Only counts loading time, not time spent scrolled away.)
    const slow = setTimeout(() => !ready && giveUp(), 4000);
    const start = () => {
      if (started) return;
      v.play().then(
        () => {
          started = true;
          clearTimeout(slow);
          card?.classList.add("lion-go");
        },
        giveUp,
      );
    };
    // Wait until the card is on screen (on phones it starts below the fold).
    const maybeStart = () => ready && seen && start();
    const io = new IntersectionObserver(
      ([e]) => {
        if (e.isIntersecting) {
          seen = true;
          io.disconnect();
          maybeStart();
        }
      },
      { threshold: 0.5 },
    );
    if (card) io.observe(card);
    const onReady = () => {
      ready = true;
      maybeStart();
    };
    v.addEventListener("canplaythrough", onReady);
    // Sources are tried in order; only the last one failing means nothing can play.
    const last = v.querySelector("source:last-of-type");
    last?.addEventListener("error", giveUp);
    return () => {
      clearTimeout(slow);
      io.disconnect();
      v.removeEventListener("canplaythrough", onReady);
      last?.removeEventListener("error", giveUp);
    };
  }, [mode]);

  if (!mode) return null;
  return (
    <>
      <div className={`hero-lion ${mode}`} aria-hidden />
      {mode === "intro" ? (
        <>
          <div className="hero-lion-shade" aria-hidden />
          <video
            ref={video}
            className="hero-lion-video"
            muted
            playsInline
            preload="auto"
            aria-hidden
            tabIndex={-1}
            disablePictureInPicture
          >
            <source src="/video/lion-pounce.webm" type="video/webm" />
            <source src="/video/lion-pounce.mp4" type="video/mp4" />
          </video>
          <div className="hero-claw" aria-hidden>
            <span />
            <span />
            <span />
          </div>
        </>
      ) : null}
    </>
  );
}
