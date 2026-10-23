"use client";

import Link from "next/link";
import { type ReactNode, useEffect, useState } from "react";
import { Search } from "./Icons";

export interface SearchEntry {
  id: number;
  /** Lower-case name, nickname and padded ID, matched against the query. */
  text: string;
  node: ReactNode;
}

const norm = (s: string) => s.trim().toLowerCase().replace(/^#/, "");

function matches(e: SearchEntry, q: string) {
  if (!q) return true;
  if (/^\d+$/.test(q) && e.id === Number(q)) return true;
  return e.text.includes(q);
}

/**
 * Riser Database search, done in the browser over the full list so the page itself stays
 * static (instant to load) instead of hitting the database on every visit.
 * ?q= in the URL still works and stays in sync for sharing.
 */
interface Member {
  handle: string;
  display_name: string;
  coins: number;
  frame: string | null;
  title: string | null;
  badge: boolean;
  riser_id: number | null;
}

export function PullerSearch({ hero, board, entries }: { hero: ReactNode; board: ReactNode; entries: SearchEntry[] }) {
  const [input, setInput] = useState("");
  const [query, setQuery] = useState("");
  const [members, setMembers] = useState<Member[]>([]);

  useEffect(() => {
    const q = (new URLSearchParams(window.location.search).get("q") ?? "").slice(0, 60);
    setInput(q);
    setQuery(q);
  }, []);

  const apply = (raw: string) => {
    const q = raw.slice(0, 60);
    setQuery(q);
    const url = new URL(window.location.href);
    if (q.trim()) url.searchParams.set("q", q.trim());
    else url.searchParams.delete("q");
    window.history.replaceState(window.history.state, "", url);
  };

  const q = norm(query);
  const shown = entries.filter((e) => matches(e, q));

  // Member accounts (people without a Riser ID too) come from the server, debounced.
  useEffect(() => {
    const term = query.trim().replace(/^@/, "");
    if (term.length < 2) {
      setMembers([]);
      return;
    }
    const ctrl = new AbortController();
    const t = setTimeout(() => {
      fetch(`/api/members?q=${encodeURIComponent(term)}`, { signal: ctrl.signal })
        .then((r) => (r.ok ? r.json() : []))
        .then(setMembers)
        .catch(() => {});
    }, 200);
    return () => {
      clearTimeout(t);
      ctrl.abort();
    };
  }, [query]);

  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          {hero}
          <form
            className="search"
            role="search"
            onSubmit={(e) => {
              e.preventDefault();
              apply(input);
            }}
          >
            <input
              name="q"
              type="search"
              value={input}
              onChange={(e) => {
                setInput(e.target.value);
                apply(e.target.value);
              }}
              placeholder="Name, @username or Riser ID, e.g. 008"
              aria-label="Search pullers"
            />
            <button className="btn btn-primary btn-sm" type="submit">
              <Search /> Search
            </button>
          </form>
          {q ? (
            <p className="search-hint" aria-live="polite">
              {shown.length} {shown.length === 1 ? "Riser" : "Risers"}
              {members.length ? (
                <>
                  {" · "}
                  <a href="#members">
                    {members.length} {members.length === 1 ? "member" : "members"} found ↓
                  </a>
                </>
              ) : null}
            </p>
          ) : null}
        </div>
      </section>

      {!q ? board : null}

      <section className="section" style={{ paddingTop: q ? 60 : 40 }}>
        <div className="wrap">
          <div className="panel-title" style={{ marginBottom: 28 }}>
            <span>{q ? `Results for “${query.trim()}”` : "All Risers"}</span>
            <small>{shown.length} FOUND</small>
          </div>
          {shown.length ? (
            <div className="puller-grid">
              {shown.map((e) => (
                <div key={e.id} style={{ display: "contents" }}>
                  {e.node}
                </div>
              ))}
            </div>
          ) : members.length ? null : (
            <div className="empty panel">
              <b>No Riser found</b>
              Try a different name or number. Not in the database yet? <Link href="/join">Register</Link> and pull at our
              next event.
            </div>
          )}

          {q && members.length ? (
            <div className="member-results" id="members">
              <div className="panel-title" style={{ margin: "48px 0 20px" }}>
                <span>Members</span>
                <small>{members.length} FOUND</small>
              </div>
              <div className="member-grid">
                {members.map((m) => (
                  <Link key={m.handle} href={`/members/${m.handle}`} className={`member-chip${m.frame ? ` mf-${m.frame}` : ""}`}>
                    <b>
                      {m.display_name}
                      {m.badge ? <i className="cl-lion" aria-label="Lion badge" /> : null}
                    </b>
                    <span>
                      @{m.handle}
                      {m.riser_id ? ` · Riser #${String(m.riser_id).padStart(3, "0")}` : ""}
                    </span>
                    {m.title ? <em>{m.title}</em> : null}
                    <small>
                      <span className="coin" aria-hidden /> {m.coins.toLocaleString("en-AU")}
                    </small>
                  </Link>
                ))}
              </div>
            </div>
          ) : null}
        </div>
      </section>
    </>
  );
}
