"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { submitArcadeScore } from "@/app/(site)/account/actions";
import { lionSays } from "@/lib/lion";

/**
 * Race to the Pin (a standalone game in public/arcade) in a frame. The game runs in
 * "embedded" mode: it waits for visibility messages from us, so it pauses itself when
 * scrolled out of view and only starts once it's on screen. Wins are reported back to us and
 * saved to the Riser's account for the leaderboard.
 */
export function ArcadeFrame({ loggedIn }: { loggedIn: boolean }) {
  const frame = useRef<HTMLIFrameElement>(null);
  const visible = useRef(false);
  const router = useRouter();
  const [note, setNote] = useState<{ text: string; ok: boolean } | null>(null);

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
      if (e.data?.type === "88-arcade-score" && typeof e.data.score === "number" && typeof e.data.level === "string") {
        submitArcadeScore(e.data.level, e.data.score)
          .then((r) => {
            setNote({ text: r.message, ok: r.saved });
            if (r.saved && r.message.startsWith("New")) {
              lionSays("flex", "New best on the board!");
              setTimeout(() => router.refresh(), 1500);
            }
          })
          .catch(() => setNote({ text: "Couldn't save that score. Try again after your next win.", ok: false }));
      }
    };
    window.addEventListener("message", onMsg);
    return () => {
      io.disconnect();
      window.removeEventListener("message", onMsg);
    };
  }, [router]);

  return (
    <>
    <iframe
      ref={frame}
      className="arcade-frame"
      src="/arcade/race-to-the-pin.html?embedded=1"
      title="Race to the Pin arm wrestling game"
      loading="lazy"
    />
    <p className={`arcade-note${note?.ok ? " ok" : ""}`} role="status" aria-live="polite">
      {note ? (
        note.ok ? (
          note.text
        ) : (
          <>
            {note.text}
            {!loggedIn ? (
              <>
                {" "}
                <Link href="/account?next=/play%23race-to-the-pin">Log in or sign up →</Link>
              </>
            ) : null}
          </>
        )
      ) : loggedIn ? (
        "Your wins are saved to the leaderboard automatically."
      ) : (
        <>
          Playing as a guest. <Link href="/account?next=/play%23race-to-the-pin">Log in</Link> to put your wins on the
          leaderboard.
        </>
      )}
    </p>
    </>
  );
}
