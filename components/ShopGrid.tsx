"use client";

import Image from "next/image";
import { useRef, useState } from "react";
import type { Product } from "@/lib/shop";
import { InterestForm } from "./InterestForm";

/** Concept products: no checkout, just a way to register interest. */
export function ShopGrid({ products }: { products: Product[] }) {
  const dialog = useRef<HTMLDialogElement>(null);
  const [open, setOpen] = useState<Product | null>(null);
  const interestDialog = useRef<HTMLDialogElement>(null);
  const [interest, setInterest] = useState<Product | null>(null);
  // Remount the form for each opening so a finished submission starts fresh next time.
  const [formKey, setFormKey] = useState(0);

  const ask = (p: Product) => {
    setInterest(p);
    setFormKey((k) => k + 1);
    interestDialog.current?.showModal();
  };

  const view = (p: Product) => {
    setOpen(p);
    dialog.current?.showModal();
  };

  return (
    <>
      <div className="shop-grid">
        {products.map((p) => {
          const art = p.sheet ?? p.image;
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
                <button type="button" className="btn btn-primary product-cta" onClick={() => ask(p)}>
                  Register interest
                </button>
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
      <dialog
        ref={interestDialog}
        className="interest-dialog"
        aria-label="Register interest"
        onClick={(e) => {
          if (e.target === e.currentTarget) interestDialog.current?.close();
        }}
        onClose={() => setInterest(null)}
      >
        {interest ? <InterestForm key={formKey} product={interest} onClose={() => interestDialog.current?.close()} /> : null}
        <button type="button" className="lightbox-btn lightbox-close" onClick={() => interestDialog.current?.close()} aria-label="Close">
          ×
        </button>
      </dialog>
    </>
  );
}
