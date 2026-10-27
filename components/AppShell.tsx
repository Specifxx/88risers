"use client";

import { useEffect } from "react";

/** Registers the service worker that makes the site installable as the 88 Risers app. */
export function AppShell() {
  useEffect(() => {
    if (process.env.NODE_ENV !== "production" || !("serviceWorker" in navigator)) return;
    navigator.serviceWorker.register("/sw.js", { scope: "/", updateViaCache: "none" }).catch(() => {});
  }, []);
  return null;
}
