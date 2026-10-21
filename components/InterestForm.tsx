"use client";

import { startTransition, useActionState } from "react";
import { registerInterest, type InterestState } from "@/app/actions";
import type { Product } from "@/lib/shop";
import { Arrow, Check } from "./Icons";

/** Name + mobile for one product. Saved for the organisers and emailed to the club. */
export function InterestForm({ product, onClose }: { product: Product; onClose: () => void }) {
  const [state, action, pending] = useActionState<InterestState, FormData>(registerInterest, { status: "idle" });

  // Submit manually so React doesn't reset the fields after a validation error.
  function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    startTransition(() => action(fd));
  }

  if (state.status === "ok") {
    return (
      <div className="form-card interest-card" aria-live="polite">
        <div className="success">
          <div className="tick">
            <Check />
          </div>
          <h3>You&apos;re on the list{state.name ? `, ${state.name}` : ""}</h3>
          <p>
            Thanks for backing the {product.name}. We&apos;ll text you if it drops. Prices and details may change before then.
          </p>
          <button type="button" className="btn btn-ghost" onClick={onClose}>
            Back to the shop
          </button>
        </div>
      </div>
    );
  }

  const err = state.status === "error" ? state : null;
  const invalid = (f: string) => (err?.field === f ? "true" : undefined);
  const notesLabel = product.id === "jersey" ? "Size, name & number" : product.id === "belt" || product.id === "tee" ? "Size" : "Anything else";
  const notesHint = product.id === "jersey" ? "e.g. L · HARRY LU · 1" : product.id === "tee" ? "e.g. M" : product.id === "belt" ? "e.g. 3" : "Optional";

  return (
    <form className="form-card interest-card" onSubmit={submit} noValidate>
      <div className="form-title">
        <h3>Register interest</h3>
        <span>
          {product.name} · {product.price}
        </span>
      </div>
      <p className="interest-lede">It&apos;s a concept for now, with nothing to buy or pay. Leave your name and number and we&apos;ll text you if it drops.</p>

      {err && !err.field ? (
        <div className="form-error" role="alert">
          {err.message}
        </div>
      ) : null}

      <input type="hidden" name="product" value={product.id} />

      <div className="field" data-invalid={invalid("name")}>
        <label htmlFor="i-name">Name</label>
        <input id="i-name" name="name" type="text" autoComplete="name" placeholder="Your name" required maxLength={80} autoFocus />
        {err?.field === "name" ? <p className="field-error">{err.message}</p> : null}
      </div>

      <div className="field" data-invalid={invalid("phone")}>
        <label htmlFor="i-phone">Mobile number</label>
        <input id="i-phone" name="phone" type="tel" inputMode="tel" autoComplete="tel" placeholder="0412 345 678" required />
        {err?.field === "phone" ? <p className="field-error">{err.message}</p> : null}
      </div>

      <div className="field">
        <label htmlFor="i-notes">
          {notesLabel} <em>optional</em>
        </label>
        <input id="i-notes" name="notes" type="text" maxLength={300} placeholder={notesHint} />
      </div>

      <div className="hp" aria-hidden>
        <label>
          Company <input name="company" type="text" tabIndex={-1} autoComplete="off" />
        </label>
      </div>

      <button className="btn btn-primary submit" type="submit" disabled={pending}>
        {pending ? "Sending…" : "Register interest"} {!pending ? <Arrow /> : null}
      </button>
      <p className="fine">Your details go only to the club organisers.</p>
    </form>
  );
}
