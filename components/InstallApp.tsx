"use client";

import { useEffect, useState } from "react";

type Prompt = Event & { prompt: () => Promise<void>; userChoice: Promise<{ outcome: "accepted" | "dismissed" }> };

/** Installs the site as the 88 Risers app: a one-tap button where the browser allows it, steps elsewhere. */
export function InstallApp() {
  const [os, setOs] = useState<"ios" | "android" | "desktop" | null>(null);
  const [installed, setInstalled] = useState(false);
  const [deferred, setDeferred] = useState<Prompt | null>(null);
  const [done, setDone] = useState(false);

  useEffect(() => {
    const ua = navigator.userAgent;
    const ios = /iPhone|iPad|iPod/i.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
    setOs(ios ? "ios" : /Android/i.test(ua) ? "android" : "desktop");
    setInstalled(window.matchMedia("(display-mode: standalone)").matches || (navigator as Navigator & { standalone?: boolean }).standalone === true);
    const onPrompt = (e: Event) => {
      e.preventDefault();
      setDeferred(e as Prompt);
    };
    const onInstalled = () => setDone(true);
    window.addEventListener("beforeinstallprompt", onPrompt);
    window.addEventListener("appinstalled", onInstalled);
    return () => {
      window.removeEventListener("beforeinstallprompt", onPrompt);
      window.removeEventListener("appinstalled", onInstalled);
    };
  }, []);

  if (installed) return <p className="install-note ok">You&apos;re already using the 88 Risers app. 🦁</p>;
  if (done) return <p className="install-note ok">Installed! Find 88 Risers on your home screen.</p>;

  return (
    <div className="install">
      {deferred ? (
        <button
          type="button"
          className="btn btn-primary install-btn"
          onClick={async () => {
            await deferred.prompt();
            const c = await deferred.userChoice;
            if (c.outcome === "accepted") setDone(true);
            setDeferred(null);
          }}
        >
          Install the app
        </button>
      ) : null}

      <div className={`install-steps${os === "ios" ? " on" : ""}`}>
        <h3>iPhone / iPad</h3>
        <ol>
          <li>
            Open <b>88risers.com</b> in <b>Safari</b>.
          </li>
          <li>
            Tap the <b>Share</b> button (the square with the arrow pointing up).
          </li>
          <li>
            Scroll down and tap <b>Add to Home Screen</b>, then <b>Add</b>.
          </li>
        </ol>
      </div>
      <div className={`install-steps${os === "android" ? " on" : ""}`}>
        <h3>Android</h3>
        <ol>
          <li>
            Open <b>88risers.com</b> in <b>Chrome</b>.
          </li>
          <li>
            Tap <b>Install the app</b> above, or the <b>⋮</b> menu → <b>Install app</b> (or <b>Add to Home screen</b>).
          </li>
        </ol>
      </div>
      <div className={`install-steps${os === "desktop" ? " on" : ""}`}>
        <h3>Computer</h3>
        <ol>
          <li>
            In Chrome or Edge, click the <b>install</b> icon at the right end of the address bar.
          </li>
        </ol>
      </div>
    </div>
  );
}
