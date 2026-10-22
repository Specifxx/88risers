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
export function PullerSearch({ hero, board, entries }: { hero: ReactNode; board: ReactNode; entries: SearchEntry[] }) {
  const [input, setInput] = useState("");
  const [query, setQuery] = useState("");

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
              placeholder="Name or Riser ID, e.g. 008"
              aria-label="Search pullers"
            />
            <button className="btn btn-primary btn-sm" type="submit">
              <Search /> Search
            </button>
          </form>
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
          ) : (
            <div className="empty panel">
              <b>No Riser found</b>
              Try a different name or number. Not in the database yet? <Link href="/join">Register</Link> and pull at our
              next event.
            </div>
          )}
        </div>
      </section>
    </>
  );
}
