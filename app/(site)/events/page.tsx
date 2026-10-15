import type { Metadata } from "next";
import Link from "next/link";
import { KIND_LABEL, upcomingCalendar } from "@/lib/calendar";
import { listEvents } from "@/lib/data";
import { fmtDay, fmtDayNum, fmtMonth, fmtShortDate, fmtTime } from "@/lib/schedule";
import { SITE } from "@/lib/site";

/** Served from cache; regenerated at most once a minute, or immediately after admin edits. */
export const revalidate = 60;

export const metadata: Metadata = {
  title: "Events",
  description: "88 Risers table time, tournaments and socials in Rhodes, Sydney — plus past results and match videos.",
};

export default async function EventsPage() {
  const [upcoming, past] = await Promise.all([upcomingCalendar(4), listEvents("past")]);

  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / Events
          </p>
          <h1 className="display">
            Events <span className="gold-text">& results</span>
          </h1>
          <p className="lede">
            Table time runs on the first Sunday of every month at {SITE.training.venue}. Tournaments and socials are
            announced here — <Link href="/join">register</Link> to get them by text.
          </p>
          <div className="btn-row" style={{ marginTop: 28 }}>
            <a className="btn btn-sm" href="/api/calendar">
              Subscribe · add all to calendar
            </a>
            <a className="btn btn-sm btn-ghost" href={SITE.instagramUrl} target="_blank" rel="noreferrer">
              @{SITE.instagramHandle}
            </a>
          </div>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 60 }}>
        <div className="wrap">
          <div className="panel-title">
            <span>Coming up</span>
            <small>{upcoming.length} SCHEDULED</small>
          </div>
          <div className="event-list">
            {upcoming.map((c) => {
              const body = (
                <>
                  <div className="event-date">
                    <b>{fmtDayNum(c.start)}</b>
                    <span>{fmtMonth(c.start)}</span>
                  </div>
                  <div>
                    <h3 style={c.cancelled ? { textDecoration: "line-through", opacity: 0.6 } : undefined}>{c.title}</h3>
                    <p>
                      {fmtDay(c.start)} · {fmtTime(c.start)}
                      {c.end ? `–${fmtTime(c.end)}` : ""} · {c.venue}
                    </p>
                  </div>
                  <span className={`pill ${c.cancelled ? "dim" : c.kind === "tournament" ? "red" : ""}`}>
                    {c.cancelled ? "Cancelled" : KIND_LABEL[c.kind] ?? "Event"}
                  </span>
                </>
              );
              return c.href ? (
                <Link key={c.key} href={c.href} className="event-row">
                  {body}
                </Link>
              ) : (
                <div key={c.key} className="event-row">
                  {body}
                </div>
              );
            })}
          </div>

          <div className="panel-title" style={{ marginTop: 80 }}>
            <span>Past events</span>
            <small>{past.length} EVENTS</small>
          </div>
          {past.length === 0 ? (
            <div className="panel empty">
              <b>History starts soon</b>
              Results and match videos from 88 Risers tournaments will be archived here.
            </div>
          ) : (
            <div className="event-list">
              {past.map((e) => (
                <Link key={e.id} href={`/events/${e.slug}`} className="event-row">
                  <div className="event-date">
                    <b>{fmtDayNum(new Date(e.starts_at))}</b>
                    <span>{fmtMonth(new Date(e.starts_at))}</span>
                  </div>
                  <div>
                    <h3>{e.title}</h3>
                    <p>
                      {fmtShortDate(new Date(e.starts_at))} · {e.match_count ? `${e.match_count} matches recorded` : "No results posted"}
                    </p>
                  </div>
                  <span className={`pill ${e.kind === "tournament" ? "red" : ""}`}>{KIND_LABEL[e.kind] ?? "Event"}</span>
                </Link>
              ))}
            </div>
          )}
        </div>
      </section>
    </>
  );
}
