import type { MetadataRoute } from "next";
import { listEvents, listPullers } from "@/lib/data";
import { SITE } from "@/lib/site";

export const revalidate = 3600;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const [pullers, events] = await Promise.all([listPullers(), listEvents("all")]);
  return [
    { url: SITE.url, changeFrequency: "weekly", priority: 1 },
    { url: `${SITE.url}/join`, priority: 0.9 },
    { url: `${SITE.url}/pullers`, changeFrequency: "weekly", priority: 0.8 },
    { url: `${SITE.url}/events`, changeFrequency: "weekly", priority: 0.8 },
    { url: `${SITE.url}/tv`, changeFrequency: "weekly", priority: 0.6 },
    { url: `${SITE.url}/gallery`, priority: 0.5 },
    { url: `${SITE.url}/shop`, priority: 0.5 },
    { url: `${SITE.url}/supermatch`, changeFrequency: "daily", priority: 0.7 },
    { url: `${SITE.url}/play`, priority: 0.5 },
    { url: `${SITE.url}/rewards`, priority: 0.4 },
    ...pullers.map((p) => ({ url: `${SITE.url}/pullers/${p.id}`, priority: 0.5 })),
    ...events.map((e) => ({ url: `${SITE.url}/events/${e.slug}`, priority: 0.6 })),
  ];
}
