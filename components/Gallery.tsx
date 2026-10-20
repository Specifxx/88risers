"use client";

import Image from "next/image";
import { useCallback, useEffect, useRef, useState } from "react";

export interface GalleryItem {
  src: string;
  w: number;
  h: number;
  title: string;
  note: string;
}

/** Rows of images at one shared height (no cropping) with a full-screen viewer. */
export function Gallery({ rows, board }: { rows: GalleryItem[][]; board?: GalleryItem }) {
  const items = rows.flat();
  const all = board ? [...items, board] : items;
  const [open, setOpen] = useState<number | null>(null);
  const dialog = useRef<HTMLDialogElement>(null);
  const touchX = useRef<number | null>(null);

  const show = useCallback((i: number) => {
    setOpen(i);
    if (!dialog.current?.open) dialog.current?.showModal();
  }, []);
  const step = useCallback(
    (d: number) => setOpen((i) => (i === null ? i : (i + d + all.length) % all.length)),
    [all.length],
  );

  useEffect(() => {
    const el = dialog.current;
    if (!el) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "ArrowRight") step(1);
      if (e.key === "ArrowLeft") step(-1);
    };
    const onClose = () => setOpen(null);
    el.addEventListener("keydown", onKey);
    el.addEventListener("close", onClose);
    return () => {
      el.removeEventListener("keydown", onKey);
      el.removeEventListener("close", onClose);
    };
  }, [step]);

  const cur = open === null ? null : all[open];

  return (
    <>
      <div className="gallery">
        {rows.map((row, r) => (
          <div key={r} className="gallery-row">
            {row.map((it) => {
              const i = items.indexOf(it);
              return (
                <button
                  key={it.src}
                  type="button"
                  className="gallery-item"
                  style={{ flexGrow: it.w / it.h, aspectRatio: `${it.w} / ${it.h}` }}
                  onClick={() => show(i)}
                  aria-label={`Open ${it.title}`}
                >
                  <Image src={it.src} alt={it.title} fill sizes="(max-width: 720px) 100vw, 60vw" />
                  <span className="gallery-cap">
                    <b>{it.title}</b>
                    <span>{it.note}</span>
                  </span>
                </button>
              );
            })}
          </div>
        ))}
      </div>
      {board ? (
        <button type="button" className="link-arrow gallery-board" onClick={() => show(items.length)}>
          View the full concept board <span>→</span>
        </button>
      ) : null}

      <dialog
        ref={dialog}
        className="lightbox"
        aria-label="Gallery viewer"
        onClick={(e) => {
          if (e.target === e.currentTarget) dialog.current?.close();
        }}
        onTouchStart={(e) => (touchX.current = e.touches[0].clientX)}
        onTouchEnd={(e) => {
          if (touchX.current === null) return;
          const dx = e.changedTouches[0].clientX - touchX.current;
          if (Math.abs(dx) > 50) step(dx < 0 ? 1 : -1);
          touchX.current = null;
        }}
      >
        {cur ? (
          <figure>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={cur.src} alt={cur.title} width={cur.w} height={cur.h} />
            <figcaption>
              <b>{cur.title}</b> · {cur.note}
              <span className="lightbox-count">
                {open! + 1} / {all.length}
              </span>
            </figcaption>
          </figure>
        ) : null}
        <button type="button" className="lightbox-btn lightbox-close" onClick={() => dialog.current?.close()} aria-label="Close">
          ×
        </button>
        <button type="button" className="lightbox-btn lightbox-prev" onClick={() => step(-1)} aria-label="Previous">
          ‹
        </button>
        <button type="button" className="lightbox-btn lightbox-next" onClick={() => step(1)} aria-label="Next">
          ›
        </button>
      </dialog>
    </>
  );
}
