import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // PGlite (local dev database) ships WASM and must not be bundled.
  serverExternalPackages: ["@electric-sql/pglite"],
  async headers() {
    // the app's service worker must never be cached, so updates reach phones straight away
    return [
      {
        source: "/sw.js",
        headers: [
          { key: "Content-Type", value: "application/javascript; charset=utf-8" },
          { key: "Cache-Control", value: "no-cache, no-store, must-revalidate" },
        ],
      },
    ];
  },
  experimental: {
    serverActions: {
      // Photos are resized in the browser first; this is headroom for the multipart envelope.
      bodySizeLimit: "6mb",
    },
    // Upgraded by `next upgrade --agent=security` (16.4.2 → 16.4.6).
    agentUpgrade: "security",
  },
};

export default nextConfig;
