"use client";

import { Analytics } from "@vercel/analytics/next";

/** Vercel Web Analytics. Admin pages are never sent: their URL contains the secret admin key. */
export function SiteAnalytics() {
  return <Analytics beforeSend={(e) => (new URL(e.url).pathname.startsWith("/admin") ? null : e)} />;
}
