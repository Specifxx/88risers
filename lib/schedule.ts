import { SITE } from "./site";

const TZ = SITE.timeZone;

/** Offset (minutes) of a time zone from UTC at a given instant. */
function tzOffset(at: Date, timeZone = TZ) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-US", {
      timeZone,
      hourCycle: "h23",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    })
      .formatToParts(at)
      .map((p) => [p.type, p.value]),
  );
  const asUtc = Date.UTC(+parts.year, +parts.month - 1, +parts.day, +parts.hour, +parts.minute, +parts.second);
  return (asUtc - at.getTime()) / 60000;
}

/** Wall-clock time in Sydney → UTC instant. */
export function sydneyTime(y: number, m: number, d: number, h = 0, min = 0) {
  const guess = Date.UTC(y, m, d, h, min);
  const off = tzOffset(new Date(guess));
  const t = guess - off * 60000;
  // Re-check across DST boundaries.
  const off2 = tzOffset(new Date(t));
  return new Date(guess - off2 * 60000);
}

function sydneyYearMonth(now: Date) {
  const p = Object.fromEntries(
    new Intl.DateTimeFormat("en-US", { timeZone: TZ, year: "numeric", month: "numeric" })
      .formatToParts(now)
      .map((x) => [x.type, x.value]),
  );
  return { y: +p.year, m: +p.month - 1 };
}

export interface Session {
  start: Date;
  end: Date;
}

function firstSunday(y: number, m: number) {
  const dow = new Date(Date.UTC(y, m, 1)).getUTCDay();
  return 1 + ((7 - dow) % 7);
}

/** The next `count` monthly table-time sessions that haven't finished yet. */
export function upcomingTrainingSessions(count = 3, now = new Date()): Session[] {
  const out: Session[] = [];
  let { y, m } = sydneyYearMonth(now);
  while (out.length < count) {
    const d = firstSunday(y, m);
    const { start, end } = SITE.training;
    const s = { start: sydneyTime(y, m, d, start.h, start.m), end: sydneyTime(y, m, d, end.h, end.m) };
    const [ry, rm, rd] = SITE.training.resumeFrom.split("-").map(Number);
    if (s.end > now && s.start >= sydneyTime(ry, rm - 1, rd)) out.push(s);
    m += 1;
    if (m > 11) {
      m = 0;
      y += 1;
    }
  }
  return out;
}

const fmt = (opts: Intl.DateTimeFormatOptions) => new Intl.DateTimeFormat("en-AU", { timeZone: TZ, ...opts });

export const fmtDay = (d: Date) => fmt({ weekday: "long", day: "numeric", month: "long" }).format(d);
export const fmtShortDate = (d: Date) => fmt({ day: "numeric", month: "short", year: "numeric" }).format(d);
export const fmtTime = (d: Date) => fmt({ hour: "numeric", minute: "2-digit" }).format(d).replace(" ", "").toLowerCase();
export const fmtMonth = (d: Date) => fmt({ month: "short" }).format(d).toUpperCase();
export const fmtDayNum = (d: Date) => fmt({ day: "numeric" }).format(d);
export const fmtWeekday = (d: Date) => fmt({ weekday: "short" }).format(d).toUpperCase();

/** "2026-11-01T19:00" in Sydney, for <input type="datetime-local">. */
export function toSydneyInput(d: Date) {
  const p = Object.fromEntries(
    fmt({ year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", hourCycle: "h23" })
      .formatToParts(d)
      .map((x) => [x.type, x.value]),
  );
  return `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}`;
}

export function fromSydneyInput(v: string) {
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/.exec(v);
  if (!m) return null;
  return sydneyTime(+m[1], +m[2] - 1, +m[3], +m[4], +m[5]);
}
