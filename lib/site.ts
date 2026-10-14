export const SITE = {
  name: "88 Risers",
  tagline: "Arm Wrestling Club",
  url: process.env.NEXT_PUBLIC_SITE_URL || "https://88-risers.vercel.app",
  email: "88risers@gmail.com",
  instagramHandle: "88risers_",
  instagramUrl: "https://www.instagram.com/88risers_/",
  federation: "AAF — Australian Arm Wrestling Federation",
  goal: 88,
  training: {
    label: "First Sunday of every month",
    venue: "Rhodes Amphitheatre",
    suburb: "Rhodes, NSW",
    start: { h: 19, m: 0 },
    end: { h: 21, m: 30 },
    timeLabel: "7:00 – 9:30 pm",
    mapsUrl: "https://www.google.com/maps/search/?api=1&query=Rhodes+Amphitheatre+Rhodes+NSW",
  },
  timeZone: "Australia/Sydney",
} as const;

export const formatId = (n: number) => `#${String(n).padStart(3, "0")}`;
