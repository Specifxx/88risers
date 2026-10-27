"use client";

import { useEffect, useMemo, useRef, useState, useTransition } from "react";
import { addLogEntry, deleteLogEntry, updateLogEntry } from "@/app/(site)/log/actions";

export type LogEntry = { id: number; day: string; body: string };

/** A starting structure for a detailed entry (optional: it's just text). */
const TEMPLATE = `Session: table / gym / rehab
Arm: R / L    Bodyweight:
Warm-up:
Exercises (sets × reps × weight):
-
Table pulls (who, result, technique):
-
Pain / niggles (where, 0–10):
Sleep / food / energy (0–10):
What worked:
What to change next time:`;

const DRAFT_KEY = "88log-draft";
const dayLabel = (d: string) =>
  new Intl.DateTimeFormat("en-AU", { weekday: "short", day: "numeric", month: "short", year: "numeric", timeZone: "UTC" }).format(new Date(`${d}T00:00:00Z`));

/** The training log: write entries, edit or delete them, search them. */
export function LogBook({ entries, today }: { entries: LogEntry[]; today: string }) {
  const [day, setDay] = useState(today);
  const [body, setBody] = useState("");
  const [msg, setMsg] = useState<{ text: string; ok: boolean } | null>(null);
  const [q, setQ] = useState("");
  const [editing, setEditing] = useState<number | null>(null);
  const [pending, start] = useTransition();
  const box = useRef<HTMLTextAreaElement>(null);

  // keep an unsent draft on this device (phones close tabs)
  useEffect(() => {
    try {
      const d = localStorage.getItem(DRAFT_KEY);
      if (d) setBody(d);
    } catch {}
  }, []);
  useEffect(() => {
    try {
      if (body) localStorage.setItem(DRAFT_KEY, body);
      else localStorage.removeItem(DRAFT_KEY);
    } catch {}
  }, [body]);

  const save = () => {
    if (!body.trim()) return;
    start(async () => {
      const r = await addLogEntry(day, body);
      setMsg({ text: r.message, ok: r.ok });
      if (r.ok) {
        setBody("");
        setDay(today);
      }
    });
  };

  const shown = useMemo(() => {
    const t = q.trim().toLowerCase();
    return t ? entries.filter((e) => e.body.toLowerCase().includes(t) || e.day.includes(t)) : entries;
  }, [entries, q]);

  return (
    <div className="logbook">
      <div className="panel log-compose">
        <div className="log-compose-head">
          <label>
            <span>Date</span>
            <input type="date" value={day} max={today} onChange={(e) => setDay(e.target.value || today)} />
          </label>
          <button
            type="button"
            className="btn btn-sm btn-ghost"
            onClick={() => {
              setBody((b) => (b.trim() ? `${b}\n\n${TEMPLATE}` : TEMPLATE));
              box.current?.focus();
            }}
          >
            + Template
          </button>
        </div>
        <textarea
          ref={box}
          value={body}
          onChange={(e) => setBody(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) save();
          }}
          placeholder="What did you train today? Weights, sets, pulls, how it felt, any pain, what clicked…"
          rows={9}
          aria-label="New log entry"
        />
        <div className="log-compose-foot">
          <small>Part of the pioneer study: club organisers can read logs. Your draft is kept on this device until you save it.</small>
          <button type="button" className="btn btn-primary" disabled={pending || !body.trim()} onClick={save}>
            {pending ? "Saving…" : "Save entry"}
          </button>
        </div>
        {msg ? <p className={`log-msg${msg.ok ? " ok" : ""}`}>{msg.text}</p> : null}
      </div>

      <div className="log-tools">
        <input type="search" value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search your log (e.g. wrist, hook, 32kg)" aria-label="Search your log" />
        <a className="btn btn-sm btn-ghost" href="/log/export?format=txt">
          Download .txt
        </a>
        <a className="btn btn-sm btn-ghost" href="/log/export?format=csv">
          Download .csv
        </a>
      </div>

      {entries.length === 0 ? (
        <p className="muted log-empty">No entries yet. Your first one starts the 90-day count.</p>
      ) : shown.length === 0 ? (
        <p className="muted log-empty">Nothing matches “{q}”.</p>
      ) : (
        <ol className="log-list">
          {shown.map((e) => (
            <li key={e.id} className="panel log-entry">
              {editing === e.id ? (
                <EditEntry entry={e} today={today} onDone={() => setEditing(null)} />
              ) : (
                <>
                  <header>
                    <b>{dayLabel(e.day)}</b>
                    <span>
                      <button type="button" className="log-link" onClick={() => setEditing(e.id)}>
                        Edit
                      </button>
                      <button
                        type="button"
                        className="log-link danger"
                        onClick={() => {
                          if (confirm("Delete this entry? This can't be undone.")) start(async () => void (await deleteLogEntry(e.id)));
                        }}
                      >
                        Delete
                      </button>
                    </span>
                  </header>
                  <p className="log-body">{e.body}</p>
                </>
              )}
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}

function EditEntry({ entry, today, onDone }: { entry: LogEntry; today: string; onDone: () => void }) {
  const [day, setDay] = useState(entry.day);
  const [body, setBody] = useState(entry.body);
  const [pending, start] = useTransition();
  const [err, setErr] = useState<string | null>(null);
  return (
    <div className="log-edit">
      <input type="date" value={day} max={today} onChange={(e) => setDay(e.target.value || entry.day)} />
      <textarea value={body} onChange={(e) => setBody(e.target.value)} rows={Math.min(18, Math.max(6, body.split("\n").length + 1))} aria-label="Edit entry" />
      {err ? <p className="log-msg">{err}</p> : null}
      <div className="log-compose-foot">
        <button type="button" className="btn btn-sm btn-ghost" onClick={onDone}>
          Cancel
        </button>
        <button
          type="button"
          className="btn btn-sm btn-primary"
          disabled={pending}
          onClick={() =>
            start(async () => {
              const r = await updateLogEntry(entry.id, day, body);
              if (r.ok) onDone();
              else setErr(r.message);
            })
          }
        >
          {pending ? "Saving…" : "Save"}
        </button>
      </div>
    </div>
  );
}
