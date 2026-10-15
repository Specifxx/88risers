"use client";

import { useEffect, useRef, useState } from "react";

/** Shown if a page fails to load. Retries once on its own before asking. */
export default function SiteError({ error, retry }: { error: Error & { digest?: string }; retry: () => void }) {
  const tried = useRef(false);
  const [busy, setBusy] = useState(true);

  useEffect(() => {
    console.error(error);
    if (tried.current) {
      setBusy(false);
      return;
    }
    tried.current = true;
    const t = setTimeout(() => {
      retry();
      setBusy(false);
    }, 1200);
    return () => clearTimeout(t);
  }, [error, retry]);

  return (
    <section className="page-hero" style={{ minHeight: "70vh", display: "flex", alignItems: "center" }}>
      <div className="wrap">
        <p className="eyebrow">{busy ? "Reconnecting" : "Lost grip"}</p>
        <h1 className="display">
          {busy ? "One sec…" : <>Hold <span className="gold-text">on.</span></>}
        </h1>
        <p className="lede">
          {busy ? "Getting the latest from the table." : "That didn't load properly. It's usually fixed by trying again."}
        </p>
        {!busy ? (
          <div className="btn-row" style={{ marginTop: 28 }}>
            <button className="btn btn-primary" onClick={() => retry()}>
              Try again
            </button>
            <a className="btn" href="/">
              Home
            </a>
          </div>
        ) : null}
      </div>
    </section>
  );
}
