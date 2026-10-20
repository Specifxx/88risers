"use client";

import Image from "next/image";
import { useRef, useState } from "react";

export interface Product {
  id: string;
  name: string;
  kind: string;
  price: string;
  blurb: string;
  details: string[];
  badge?: string;
  /** Card image; leave out for "artwork coming" placeholder. */
  image?: { src: string; w: number; h: number; bg?: string };
  /** Full concept sheet shown in the viewer. */
  sheet?: { src: string; w: number; h: number };
}

/** Concept products: no checkout, just a way to register interest. */
export function ShopGrid({ products, email }: { products: Product[]; email: string }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const [open, setOpen] = useState<Product | null>(null);

  const view = (p: Product) => {
    setOpen(p);
    dialog.current?.showModal();
  };

  return (
    <>
      <div className="shop-grid">
        {products.map((p) => {
          const art = p.sheet ?? p.image;
          const mail = `mailto:${email}?subject=${encodeURIComponent(`Shop interest: ${p.name}`)}&body=${encodeURIComponent(
            `Hi 88 Risers,\n\nI'd be keen on the ${p.name} (${p.price}) when it drops.\n\nName:\nSize / options:\n`,
          )}`;
          return (
            <article key={p.id} className="product" data-reveal>
              {p.image ? (
                <button
                  type="button"
                  className="product-media"
                  style={{ background: p.image.bg }}
                  onClick={() => art && view(p)}
                  aria-label={`View the ${p.name} concept`}
                >
                  <Image src={p.image.src} alt={`${p.name} concept`} fill sizes="(max-width: 720px) 100vw, 400px" />
                  <span className="product-zoom">View concept</span>
                </button>
              ) : (
                <div className="product-media product-ph" aria-hidden>
                  <Image src="/crest.jpg" alt="" width={96} height={96} />
                  <span>Artwork in the works</span>
                </div>
              )}
              <div className="product-body">
                <div className="product-top">
                  <span className="product-kind">{p.kind}</span>
                  {p.badge ? <span className="product-badge">{p.badge}</span> : null}
                </div>
                <h2 className="product-name">{p.name}</h2>
                <p className="product-price gold-text">{p.price}</p>
                <p className="product-blurb">{p.blurb}</p>
                <ul className="product-details">
                  {p.details.map((d) => (
                    <li key={d}>{d}</li>
                  ))}
                </ul>
                <a className="btn btn-primary product-cta" href={mail}>
                  Register interest
                </a>
              </div>
            </article>
          );
        })}
      </div>

      <dialog
        ref={dialog}
        className="lightbox"
        aria-label="Product concept"
        onClick={(e) => {
          if (e.target === e.currentTarget) dialog.current?.close();
        }}
        onClose={() => setOpen(null)}
      >
        {open && (open.sheet ?? open.image) ? (
          <figure>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={(open.sheet ?? open.image)!.src}
              alt={`${open.name} concept sheet`}
              width={(open.sheet ?? open.image)!.w}
              height={(open.sheet ?? open.image)!.h}
            />
            <figcaption>
              <b>{open.name}</b> · {open.price} · Concept
            </figcaption>
          </figure>
        ) : null}
        <button type="button" className="lightbox-btn lightbox-close" onClick={() => dialog.current?.close()} aria-label="Close">
          ×
        </button>
      </dialog>
    </>
  );
}
