"use client";

import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { RADIO } from "@/lib/radio";

type Status = "idle" | "tuning" | "playing" | "paused" | "error";
const STORE = "88fm";
/** Give a station this long to start before trying the next one. */
const TUNE_TIMEOUT = 12_000;

/**
 * 88Risers FM: what 88RisersTV plays between live broadcasts. Three channels of licensed
 * internet radio; if a station is down it quietly tunes to the next one on that channel.
 */
export function TvRadio({
  event,
}: {
  event: { kind: string; title: string; detail: string; href: string } | null;
}) {
  const audio = useRef<HTMLAudioElement>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [ch, setCh] = useState(0);
  const [st, setSt] = useState(0);
  const [status, setStatus] = useState<Status>("idle");
  const [vol, setVol] = useState(0.8);
  /** iPhones ignore page volume (hardware buttons only), so the slider is hidden there. */
  const [canVol, setCanVol] = useState(true);
  useEffect(() => {
    const t = new Audio();
    t.volume = 0.5;
    if (t.volume !== 0.5) setCanVol(false);
  }, []);
  const channel = RADIO[ch];
  const station = channel.stations[st];

  // Remember the last channel and volume (nice to have; fine if storage is blocked).
  useEffect(() => {
    try {
      const saved = JSON.parse(localStorage.getItem(STORE) ?? "{}");
      const i = RADIO.findIndex((c) => c.id === saved.ch);
      if (i >= 0) setCh(i);
      if (typeof saved.vol === "number")
        setVol(Math.min(1, Math.max(0, saved.vol)));
    } catch {}
  }, []);
  useEffect(() => {
    try {
      localStorage.setItem(STORE, JSON.stringify({ ch: RADIO[ch].id, vol }));
    } catch {}
    if (audio.current) audio.current.volume = vol;
  }, [ch, vol]);

  const clearTimer = () => {
    if (timer.current) clearTimeout(timer.current);
    timer.current = null;
  };

  const tune = useCallback((c: number, s: number) => {
    const a = audio.current;
    if (!a) return;
    const stations = RADIO[c].stations;
    if (s >= stations.length) {
      clearTimer();
      a.removeAttribute("src");
      a.load();
      setStatus("error");
      return;
    }
    setCh(c);
    setSt(s);
    setStatus("tuning");
    clearTimer();
    timer.current = setTimeout(() => tune(c, s + 1), TUNE_TIMEOUT);
    a.src = stations[s].url;
    a.play().catch((err: unknown) => {
      // Autoplay blocked: wait for a tap. Anything else: try the next station.
      if (err instanceof DOMException && err.name === "NotAllowedError") {
        clearTimer();
        setStatus("paused");
      } else tune(c, s + 1);
    });
  }, []);

  useEffect(() => {
    const a = audio.current;
    if (!a) return;
    const playing = () => {
      clearTimer();
      setStatus("playing");
    };
    const paused = () => setStatus((s) => (s === "playing" ? "paused" : s));
    a.addEventListener("playing", playing);
    a.addEventListener("pause", paused);
    return () => {
      a.removeEventListener("playing", playing);
      a.removeEventListener("pause", paused);
      clearTimer();
    };
  }, []);

  // Lock screen / headphone controls.
  useEffect(() => {
    if (!("mediaSession" in navigator) || status !== "playing") return;
    navigator.mediaSession.metadata = new MediaMetadata({
      title: `${channel.name} · ${station.name}`,
      artist: "88Risers FM",
      album: channel.tag,
      artwork: [{ src: "/apple-icon.png", type: "image/png" }],
    });
  }, [status, channel, station]);

  const onError = () => {
    if (status === "tuning" || status === "playing") tune(ch, st + 1);
  };

  const toggle = () => {
    const a = audio.current;
    if (!a) return;
    if (status === "playing" || status === "tuning") {
      clearTimer();
      a.pause();
      a.removeAttribute("src"); // stop downloading a live stream while paused
      a.load();
      setStatus("paused");
    } else tune(ch, status === "error" ? 0 : st);
  };

  const on = status === "playing";
  const live = on || status === "tuning";
  const needle = RADIO.length > 1 ? 12 + (ch / (RADIO.length - 1)) * 76 : 50;

  return (
    <div className={`fm${on ? " fm-on" : ""}`}>
      {event ? (
        <Link href={event.href} className="fm-event">
          <span className="fm-event-dot" aria-hidden />
          <b>
            {event.kind === "supermatch"
              ? "Supermatch on now"
              : "Tournament day"}
          </b>
          <span>
            {event.kind === "supermatch"
              ? `${event.title}: ${event.detail}`
              : event.detail}
            . Live feed coming soon.
          </span>
          <em>
            {event.kind === "supermatch" ? "Back your pick ›" : "Details ›"}
          </em>
        </Link>
      ) : null}

      <div className="fm-deck">
        <div className="fm-top">
          <div>
            <p className="fm-brand">
              88<span>Risers</span> FM
            </p>
            <p className="fm-sponsor">Presented by Supp Station</p>
          </div>
          <p className={`fm-onair${on ? " lit" : ""}`}>
            <i aria-hidden />{" "}
            {on ? "On air" : status === "tuning" ? "Tuning…" : "Radio"}
          </p>
        </div>

        <div className="fm-lcd" aria-live="polite">
          <div className="fm-freq">
            {channel.freq}
            <small>FM</small>
          </div>
          <div className="fm-now">
            <b>{channel.name}</b>
            <span>
              {status === "error"
                ? "All stations on this channel are down. Try another."
                : status === "idle"
                  ? channel.tag
                  : `${channel.tag} · ${station.name}`}
            </span>
          </div>
          <div className="fm-eq" aria-hidden>
            {Array.from({ length: 14 }, (_, i) => (
              <i
                key={i}
                style={{
                  animationDelay: `${(i * 137) % 900}ms`,
                  animationDuration: `${620 + ((i * 89) % 420)}ms`,
                }}
              />
            ))}
          </div>
        </div>

        <div className="fm-dial" aria-hidden>
          <div className="fm-scale">
            {Array.from({ length: 41 }, (_, i) => (
              <i key={i} className={i % 5 === 0 ? "major" : undefined} />
            ))}
          </div>
          <span className="fm-needle" style={{ left: `${needle}%` }} />
        </div>

        <div className="fm-presets" role="radiogroup" aria-label="Channel">
          {RADIO.map((c, i) => (
            <button
              key={c.id}
              type="button"
              role="radio"
              aria-checked={i === ch}
              className={i === ch ? "on" : undefined}
              onClick={() => (i === ch && live ? undefined : tune(i, 0))}
            >
              <small>{c.freq}</small>
              <b>{c.name}</b>
              <span>{c.tag}</span>
            </button>
          ))}
        </div>

        <div className="fm-controls">
          <button
            type="button"
            className="fm-play"
            onClick={toggle}
            aria-label={live ? "Pause the radio" : "Play the radio"}
          >
            {live ? (
              <svg viewBox="0 0 24 24" aria-hidden>
                <rect x="6" y="5" width="4" height="14" rx="1" />
                <rect x="14" y="5" width="4" height="14" rx="1" />
              </svg>
            ) : (
              <svg viewBox="0 0 24 24" aria-hidden>
                <path d="M8 5.5v13a1 1 0 0 0 1.5.86l10.5-6.5a1 1 0 0 0 0-1.72L9.5 4.64A1 1 0 0 0 8 5.5Z" />
              </svg>
            )}
          </button>
          {canVol ? (
            <label className="fm-vol">
              <span>Vol</span>
              <input
                type="range"
                min={0}
                max={1}
                step={0.01}
                value={vol}
                onChange={(e) => setVol(Number(e.target.value))}
                aria-label="Volume"
              />
            </label>
          ) : null}
        </div>
        <audio ref={audio} preload="none" onError={onError} />
      </div>
      <p className="fm-credit">
        Live internet radio from independent stations, found via
        radio-browser.info. When a supermatch is on, this screen switches to the
        live feed.
      </p>
    </div>
  );
}
