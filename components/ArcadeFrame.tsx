"use client";

import { useEffect, useRef } from "react";

/**
 * Race to the Pin (a standalone game in public/arcade) in a frame. The game runs in
 * "embedded" mode: it waits for visibility messages from us, so it pauses itself when
 * scrolled out of view and only starts once it's on screen.
 */
export function ArcadeFrame() {
  const frame = useRef<HTMLIFrameElement>(null);
  const visible = useRef(false);

  useEffect(() => {
    const el = frame.current;
    if (!el) return;
    const tell = () => el.contentWindow?.postMessage({ type: "88-arcade-visibility", visible: visible.current }, window.location.origin);
    const io = new IntersectionObserver(
      ([e]) => {
        visible.current = e.isIntersecting && e.intersectionRatio > 0.4;
        tell();
      },
      { threshold: [0, 0.4, 0.6] },
    );
    io.observe(el);
    const onMsg = (e: MessageEvent) => {
      if (e.origin !== window.location.origin || e.source !== el.contentWindow) return;
      if (e.data?.type === "88-arcade-ready") tell();
      if (e.data?.type === "88-arcade-close") el.blur();
    };
    window.addEventListener("message", onMsg);
    return () => {
      io.disconnect();
      window.removeEventListener("message", onMsg);
    };
  }, []);

  return (
    <iframe
      ref={frame}
      className="arcade-frame"
      src="/arcade/race-to-the-pin.html?embedded=1"
      title="Race to the Pin arm wrestling game"
      loading="lazy"
    />
  );
}
