import { upcomingCalendar } from "@/lib/calendar";
import { SITE } from "@/lib/site";

const stamp = (d: Date) => d.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
const esc = (s: string) => s.replace(/[\;,]/g, (c) => `\\${c}`).replace(/\n/g, "\\n");

/** .ics download for the upcoming calendar (or one item via ?start=ISO). */
export async function GET(req: Request) {
  const start = new URL(req.url).searchParams.get("start");
  let items = (await upcomingCalendar(6)).filter((c) => !c.cancelled);
  if (start) items = items.filter((c) => c.start.toISOString() === start);

  const lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//88 Risers//Events//EN", "CALSCALE:GREGORIAN", "METHOD:PUBLISH"];
  for (const c of items) {
    const end = c.end ?? new Date(c.start.getTime() + 3 * 3600_000);
    lines.push(
      "BEGIN:VEVENT",
      `UID:${c.key}@88risers`,
      `DTSTAMP:${stamp(new Date())}`,
      `DTSTART:${stamp(c.start)}`,
      `DTEND:${stamp(end)}`,
      `SUMMARY:${esc(`88 Risers — ${c.title}`)}`,
      `LOCATION:${esc(`${c.venue}, ${SITE.training.suburb}`)}`,
      `DESCRIPTION:${esc(`${c.description ?? ""}\n${SITE.instagramUrl}`)}`,
      "END:VEVENT",
    );
  }
  lines.push("END:VCALENDAR");
  return new Response(lines.join("\r\n"), {
    headers: {
      "Content-Type": "text/calendar; charset=utf-8",
      "Content-Disposition": `attachment; filename="88risers.ics"`,
    },
  });
}
