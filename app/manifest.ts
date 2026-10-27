import type { MetadataRoute } from "next";

/** Lets the site install to a phone's home screen as the 88 Risers app. */
export default function manifest(): MetadataRoute.Manifest {
  return {
    id: "/",
    name: "88 Risers Arm Wrestling Club",
    short_name: "88 Risers",
    description: "The 88 Risers arm wrestling club: events, the Riser database, supermatches, Pin Run and your training log.",
    start_url: "/?source=app",
    scope: "/",
    display: "standalone",
    orientation: "portrait",
    background_color: "#0a0908",
    theme_color: "#0a0908",
    categories: ["sports", "games", "lifestyle"],
    icons: [
      { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
      { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png", purpose: "any" },
      { src: "/icons/maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
    ],
    shortcuts: [
      { name: "Play Pin Run", short_name: "Play", url: "/play", icons: [{ src: "/icons/icon-192.png", sizes: "192x192" }] },
      { name: "Training log", short_name: "Log", url: "/log", icons: [{ src: "/icons/icon-192.png", sizes: "192x192" }] },
      { name: "Supermatch", short_name: "Supermatch", url: "/supermatch", icons: [{ src: "/icons/icon-192.png", sizes: "192x192" }] },
    ],
  };
}
