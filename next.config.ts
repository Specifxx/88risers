import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // PGlite (local dev database) ships WASM and must not be bundled.
  serverExternalPackages: ["@electric-sql/pglite"],
  experimental: {
    serverActions: {
      // Photos are resized in the browser first; this is headroom for the multipart envelope.
      bodySizeLimit: "6mb",
    },
  },
};

export default nextConfig;
