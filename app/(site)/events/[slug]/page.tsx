import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Avatar } from "@/components/Avatar";
import { Calendar, Pin } from "@/components/Icons";
import { VideoToggle } from "@/components/VideoToggle";
import { KIND_LABEL } from "@/lib/calendar";
import { getEventBySlug, getEventMatches } from "@/lib/data";
import { fmtDay, fmtTime } from "@/lib/schedule";
import { SITE, formatId } from "@/lib/site";

/** Served from cache; regenerated at most once a minute, or immediately after admin edits. */
export const revalidate = 60;

// Pages are generated on first visit, then cached.
export function generateStaticParams() {
  return [];
}

export async function generateMetadata({ params }: PageProps<"/events/[slug]">): Promise<Metadata> {
  const e = await getEventBySlug((await params).slug);
  if (!e) return { title: "Event not found" };
  return { title: e.title, description: e.description ?? `${e.title} — an 88 Risers event.` };
}

export default async function EventPage({ params }: PageProps<"/events/[slug]">) {
  const e = await getEventBySlug((await params).slug);
  if (!e) notFound();
  const matches = await getEventMatches(e.id);
  const start = new Date(e.starts_at);
  const end = e.ends_at ? new Date(e.ends_at) : null;
  const upcoming = (end ?? new Date(start.getTime() + 4 * 3600_000)) > new Date();
  const mapUrl = e.address
    ? `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(e.address)}`
    : SITE.training.mapsUrl;

  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / <Link href="/events">Events</Link> / {e.title}
          </p>
          <div className="profile-tags" style={{ marginBottom: 18 }}>
            <span className={`pill ${e.kind === "tournament" ? "red" : ""}`}>{KIND_LABEL[e.kind] ?? "Event"}</span>
            {e.cancelled ? <span className="pill dim">Cancelled</span> : upcoming ? <span className="pill">Upcoming</span> : null}
          </div>
          <h1 className="display" style={e.cancelled ? { textDecoration: "line-through" } : undefined}>
            {e.title}
          </h1>
          <dl className="facts" style={{ marginTop: 34, maxWidth: 720 }}>
            <div>
              <dt>When</dt>
              <dd>
                {fmtDay(start)} · {fmtTime(start)}
                {end ? `–${fmtTime(end)}` : ""}
              </dd>
            </div>
            <div>
              <dt>Where</dt>
              <dd>
                {e.venue || SITE.training.venue}
                {e.address ? <span className="muted"> · {e.address}</span> : null}
              </dd>
            </div>
          </dl>
          {e.description ? (
            <div className="prose">
              {e.description.split(/\n{2,}/).map((para, i) => (
                <p key={i}>{para}</p>
              ))}
            </div>
          ) : null}
          {upcoming && !e.cancelled ? (
            <div className="btn-row" style={{ marginTop: 26 }}>
              <Link className="btn btn-primary btn-sm" href="/join">
                Register to get event texts
              </Link>
              <a className="btn btn-sm" href={mapUrl} target="_blank" rel="noreferrer">
                <Pin /> Directions
              </a>
              <a className="btn btn-sm btn-ghost" href={`/api/calendar?start=${start.toISOString()}`}>
                <Calendar /> Add to calendar
              </a>
            </div>
          ) : null}
        </div>
      </section>

      {matches.length ? (
        <section className="section" style={{ paddingTop: 60 }}>
          <div className="wrap">
            <div className="panel-title">
              <span>Results</span>
              <small>{matches.length} MATCHES</small>
            </div>
            {matches.map((m) => (
              <div className="versus" key={m.id}>
                <Link href={`/pullers/${m.winner_id}`} className="side won">
                  <Avatar src={m.winner_photo} name={m.winner_name} size={46} />
                  <div style={{ minWidth: 0 }}>
                    <b>{m.winner_name}</b>
                    <small>
                      WIN · {formatId(m.winner_id)}
                      {m.winner_elo_after != null && m.winner_elo_before != null
                        ? ` · +${m.winner_elo_after - m.winner_elo_before}`
                        : ""}
                    </small>
                  </div>
                </Link>
                <div className="vs">
                  {m.is_title_match ? "★" : "VS"}
                  <small>
                    {[m.round, m.weight_class, `${m.arm} arm`, m.score].filter(Boolean).join(" · ")}
                  </small>
                </div>
                <Link href={`/pullers/${m.loser_id}`} className="side right lost">
                  <Avatar src={m.loser_photo} name={m.loser_name} size={46} />
                  <div style={{ minWidth: 0 }}>
                    <b>{m.loser_name}</b>
                    <small>
                      {formatId(m.loser_id)} · LOSS
                    </small>
                  </div>
                </Link>
                {m.video_url ? <VideoToggle url={m.video_url} /> : null}
              </div>
            ))}
          </div>
        </section>
      ) : null}
    </>
  );
}
