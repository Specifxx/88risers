"use client";

import { useState } from "react";
import { videoEmbed } from "@/lib/video";
import { ArrowUpRight, Play } from "./Icons";

export function VideoToggle({ url, label = "Watch match" }: { url: string; label?: string }) {
  const [open, setOpen] = useState(false);
  const embed = videoEmbed(url);
  if (!embed) {
    return (
      <a className="video-btn" href={url} target="_blank" rel="noreferrer">
        <ArrowUpRight /> {label}
      </a>
    );
  }
  return (
    <>
      <button type="button" className="video-btn" onClick={() => setOpen((o) => !o)} aria-expanded={open}>
        <Play /> {open ? "Hide video" : label}
      </button>
      {open ? (
        <div className={`video-frame ${embed.tall ? "tall" : ""}`}>
          {embed.kind === "video" ? (
            <video src={embed.src} controls playsInline autoPlay />
          ) : (
            <iframe
              src={embed.src}
              title="Match video"
              allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
              allowFullScreen
              loading="lazy"
            />
          )}
        </div>
      ) : null}
    </>
  );
}
