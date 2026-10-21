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

  // Play the pounce once the card is on screen. iPhones don't download video until play() is
  // called, so don't wait for buffering there: ask to play, and start the clock once it does.
  useEffect(() => {
    const v = video.current;
    if (mode !== "intro" || !v) return;
    const card = v.parentElement;
    // Safari checks the muted attribute (not just the property) before allowing autoplay.
    v.muted = true;
    v.setAttribute("muted", "");
    let started = false;
    let asked = false;
    let giveUpTimer: ReturnType<typeof setTimeout> | undefined;
    let waitTimer: ReturnType<typeof setTimeout> | undefined;
    const giveUp = () => {
      if (started) return;
      v.pause();
      setMode("rest");
    };
    const play = () => {
      if (asked) return;
      asked = true;
      clearTimeout(waitTimer);
      giveUpTimer = setTimeout(giveUp, 6000); // never got going (slow network, Low Power Mode…)
      v.play().catch(giveUp);
    };
    const onPlaying = () => {
      if (started) return;
      started = true;
      clearTimeout(giveUpTimer);
      card?.classList.add("lion-go");
    };
    const io = new IntersectionObserver(
      ([e]) => {
        if (!e.isIntersecting) return;
        io.disconnect();
        // Desktop browsers have usually buffered it by now; give them a moment if not.
        if (v.readyState >= 3) play();
        else waitTimer = setTimeout(play, 1200);
      },
      { threshold: 0.5 },
    );
    if (card) io.observe(card);
    // Buffered while we were waiting: go now rather than at the end of the grace period.
    const onReady = () => {
      if (waitTimer && !asked) play();
    };
    v.addEventListener("playing", onPlaying);
    v.addEventListener("canplaythrough", onReady);
    // Sources are tried in order; only the last one failing means nothing can play.
    const last = v.querySelector("source:last-of-type");
    last?.addEventListener("error", giveUp);
    return () => {
      clearTimeout(giveUpTimer);
      clearTimeout(waitTimer);
      io.disconnect();
      v.removeEventListener("playing", onPlaying);
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
            {/* MP4 first: Safari and iPhones play H.264 natively; WebM covers builds without it. */}
            <source src="/video/lion-pounce.mp4" type="video/mp4" />
            <source src="/video/lion-pounce.webm" type="video/webm" />
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
