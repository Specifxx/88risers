"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import type { LionMood } from "@/lib/lion";

const HIDE_KEY = "88r-merch-lion-hidden";
const LINES = ["Fresh gear from the den.", "Rep the table. See the merch.", "The lion approves this drip."];

type Mood = LionMood | "idle" | "sleepy";

/** Sydney hour, so the lion keeps club time wherever the visitor is. */
const sydneyHour = () => Number(new Intl.DateTimeFormat("en-AU", { timeZone: "Australia/Sydney", hour: "numeric", hourCycle: "h23" }).format(new Date()));

/**
 * The club's lion mascot in the corner. It nudges visitors to the shop, and reacts:
 * roars when someone claims a Riser ID or locks in a supermatch pick, cheers on rewards,
 * flexes on the leaderboards, and dozes off late at night (Sydney time).
 * Other components trigger reactions with lionSays() from lib/lion.
 */
export function MerchLion() {
  const path = usePathname();
  const [show, setShow] = useState(false);
  const [talk, setTalk] = useState(false);
  const [mood, setMood] = useState<Mood>("idle");
  const [line, setLine] = useState(LINES[0]);
  const [sub, setSub] = useState("Club tees, comp jerseys & grip gear");
  const hideTalk = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);

  const off = path.startsWith("/shop") || path.startsWith("/admin") || path.startsWith("/play");
  const board = path.startsWith("/pullers") || path.startsWith("/supermatch");

  const say = (m: Mood, text: string, subtext: string, ms = 7000) => {
    setMood(m);
    setLine(text);
    setSub(subtext);
    setShow(true);
    setTalk(true);
    clearTimeout(hideTalk.current);
    hideTalk.current = setTimeout(() => {
      setTalk(false);
      setMood((cur) => (cur === "sleepy" ? cur : "idle"));
    }, ms);
  };

  // Ambient appearance per page.
  useEffect(() => {
    if (off) return;
    let hidden = false;
    try {
      hidden = sessionStorage.getItem(HIDE_KEY) === "1";
    } catch {}
    if (hidden) return;
    const h = sydneyHour();
    const night = h >= 22 || h < 6;
    const wait = path === "/" ? 7000 : 2500;
    const t = setTimeout(() => {
      if (night) say("sleepy", "Yawn… the table's closed.", "Come pull on the first Sunday. Merch is in the shop.");
      else if (board) say("flex", "Strong table up top.", "Climb the ranks, then rep it in club gear.");
      else say("idle", LINES[Math.floor(Math.random() * LINES.length)], "Club tees, comp jerseys & grip gear");
    }, wait);
    return () => clearTimeout(t);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [path, off]);

  // Reactions from elsewhere on the site.
  useEffect(() => {
    const on = (e: Event) => {
      const d = (e as CustomEvent<{ mood: LionMood; text: string }>).detail;
      if (!d) return;
      say(d.mood, d.text, d.mood === "roar" ? "Welcome to the pride." : "Spend your coins in the reward store.", 6000);
    };
    window.addEventListener("88r:lion", on);
    return () => window.removeEventListener("88r:lion", on);
  }, []);

  if (off || !show) return null;

  const dismiss = () => {
    setShow(false);
    try {
      sessionStorage.setItem(HIDE_KEY, "1");
    } catch {}
  };

  return (
    <div className={`merch-lion mood-${mood}`} onMouseEnter={() => setTalk(true)} onMouseLeave={() => setTalk(false)}>
      <div className={`merch-bubble${talk ? " on" : ""}`} role="status">
        <b>{line}</b>
        <span>{sub}</span>
        <Link href={mood === "cheer" ? "/rewards" : "/shop"} className="merch-go">
          {mood === "cheer" ? "Reward store →" : "Visit the shop →"}
        </Link>
      </div>
      <Link href="/shop" className="merch-badge" aria-label="Check out 88 Risers club merch in the shop">
        <span className="merch-face" aria-hidden />
        {mood === "sleepy" ? (
          <span className="merch-zzz" aria-hidden>
            <i>z</i>
            <i>z</i>
            <i>Z</i>
          </span>
        ) : null}
        {mood === "roar" ? <span className="merch-roar" aria-hidden /> : null}
        {mood === "flex" ? (
          <span className="merch-flex" aria-hidden>
            💪
          </span>
        ) : null}
        <span className="merch-tag" aria-hidden>
          {mood === "sleepy" ? "ZZZ" : "MERCH"}
        </span>
      </Link>
      <button type="button" className="merch-x" onClick={dismiss} aria-label="Hide the lion">
        ×
      </button>
    </div>
  );
}
