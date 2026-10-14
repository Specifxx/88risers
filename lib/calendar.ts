import "server-only";
import { listEvents, type ClubEvent } from "./data";
import { fmtShortDate, upcomingTrainingSessions } from "./schedule";
import { SITE } from "./site";

export interface CalendarItem {
  key: string;
  title: string;
  kind: string;
  start: Date;
  end: Date | null;
  venue: string;
  description: string | null;
  href: string | null;
  cancelled: boolean;
}

const fromEvent = (e: ClubEvent): CalendarItem => ({
  key: `e${e.id}`,
  title: e.title,
  kind: e.kind,
  start: new Date(e.starts_at),
  end: e.ends_at ? new Date(e.ends_at) : null,
  venue: e.venue || SITE.training.venue,
  description: e.description,
  href: `/events/${e.slug}`,
  cancelled: e.cancelled,
});

/**
 * Upcoming events published by admins, plus the recurring first-Sunday table
 * time. An admin event on the same day as a training session replaces it, which
 * is how a session gets moved, renamed or cancelled.
 */
export async function upcomingCalendar(trainingCount = 3): Promise<CalendarItem[]> {
  const events = (await listEvents("upcoming")).map(fromEvent);
  const taken = new Set(events.map((e) => fmtShortDate(e.start)));
  const sessions = upcomingTrainingSessions(trainingCount)
    .filter((s) => !taken.has(fmtShortDate(s.start)))
    .map<CalendarItem>((s) => ({
      key: `t${s.start.getTime()}`,
      title: "Table Time",
      kind: "training",
      start: s.start,
      end: s.end,
      venue: SITE.training.venue,
      description: "Monthly meet: pulls, technique and good company. Energy drinks and snacks on us.",
      href: null,
      cancelled: false,
    }));
  return [...events, ...sessions].sort((a, b) => a.start.getTime() - b.start.getTime());
}

export const KIND_LABEL: Record<string, string> = {
  training: "Table time",
  tournament: "Tournament",
  social: "Social",
  other: "Event",
};
