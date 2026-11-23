"use client";

import { startTransition, useActionState, useState } from "react";
import { orderMoments, type MomentState } from "@/app/(site)/moments/actions";
import { MOMENTS_FULL_SET, MOMENT_EVENTS, MOMENT_ITEMS, SHIRT_SIZES, momentsTotal } from "@/lib/momentsConfig";
import { SITE } from "@/lib/site";
import { Arrow, Check, Instagram } from "./Icons";

/** 88 Moments order: pick the event and moment, choose pieces, see the total. Pay later. */
export function MomentsForm() {
  const [state, action, pending] = useActionState<MomentState, FormData>(orderMoments, { status: "idle" });
  const [picked, setPicked] = useState<string[]>(["framed"]);
  const [event, setEvent] = useState("");
  const total = momentsTotal(picked);
  const all = picked.length === MOMENT_ITEMS.length;

  function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    startTransition(() => action(fd));
  }

  if (state.status === "ok") {
    return (
      <div className="form-card" aria-live="polite">
        <div className="success">
          <div className="tick">
            <Check />
          </div>
          <h3>Order received{state.name ? `, ${state.name}` : ""}</h3>
          <p>
            {state.count} {state.count === 1 ? "piece" : "pieces"} · <b>${state.total}</b>. We&apos;ll pick your best shots, send you a
            preview of the artwork, and only ask you to pay once you&apos;re happy with it.
          </p>
          <a className="ig-card" href={SITE.instagramUrl} target="_blank" rel="noreferrer">
            <Instagram />
            <div>
              <b>Follow @{SITE.instagramHandle}</b>
              <span>New pieces from every event are posted there.</span>
            </div>
            <i>FOLLOW</i>
          </a>
        </div>
      </div>
    );
  }

  const err = state.status === "error" ? state : null;
  const invalid = (f: string) => (err?.field === f ? "true" : undefined);
  const fieldErr = (f: string) => (err?.field === f ? <p className="field-error">{err.message}</p> : null);
  const toggle = (id: string) => setPicked((p) => (p.includes(id) ? p.filter((x) => x !== id) : [...p, id]));

  return (
    <form className="form-card" onSubmit={submit} noValidate id="order">
      <div className="form-title">
        <h3>Order</h3>
        <span>Pay after you approve</span>
      </div>
      {err && !err.field ? (
        <div className="form-error" role="alert">
          {err.message}
        </div>
      ) : null}

      <div className="field" data-invalid={invalid("items")}>
        <span className="label">Pieces</span>
        <div className="mo-items">
          {MOMENT_ITEMS.map((i) => (
            <label key={i.id} className={picked.includes(i.id) ? "on" : undefined}>
              <input type="checkbox" name="items" value={i.id} checked={picked.includes(i.id)} onChange={() => toggle(i.id)} />
              <span className="mo-item-name">{i.name}</span>
              <b>${i.price}</b>
            </label>
          ))}
        </div>
        <button type="button" className="mo-all" onClick={() => setPicked(all ? ["framed"] : MOMENT_ITEMS.map((i) => i.id))}>
          {all ? "Just the framed print" : `The full set · $${MOMENTS_FULL_SET}`}
        </button>
        {fieldErr("items")}
      </div>

      {picked.includes("shirt") ? (
        <div className="field" data-invalid={invalid("shirt_size")}>
          <label htmlFor="m-size">Shirt size</label>
          <select id="m-size" name="shirt_size" defaultValue="">
            <option value="" disabled>
              Pick a size
            </option>
            {SHIRT_SIZES.map((z) => (
              <option key={z}>{z}</option>
            ))}
          </select>
          {fieldErr("shirt_size")}
        </div>
      ) : null}

      <div className="field" data-invalid={invalid("event")}>
        <label htmlFor="m-event">Event</label>
        <select id="m-event" name="event" value={event} onChange={(e) => setEvent(e.target.value)}>
          <option value="" disabled>
            Which event?
          </option>
          {MOMENT_EVENTS.map((ev) => (
            <option key={ev}>{ev}</option>
          ))}
        </select>
        {event === "Other event" ? <input name="event_other" type="text" placeholder="Event name and date" maxLength={120} style={{ marginTop: 8 }} /> : null}
        {fieldErr("event")}
      </div>
      <div className="field" data-invalid={invalid("moment")}>
        <label htmlFor="m-moment">Your moment</label>
        <textarea
          id="m-moment"
          name="moment"
          rows={3}
          maxLength={600}
          placeholder="Who you pulled, which arm, roughly when. The final? The comeback? The roar after the pin?"
        />
        {fieldErr("moment") ?? <p className="field-hint">We shoot Risers' matches at 88 events and Nationals, and pick the best frames for you.</p>}
      </div>

      <div className="field" data-invalid={invalid("riser")}>
        <label htmlFor="m-riser">
          Riser ID <em>Risers only</em>
        </label>
        <input id="m-riser" name="riser_id" type="text" inputMode="numeric" placeholder="e.g. 017" maxLength={5} />
        {fieldErr("riser") ?? (
          <p className="field-hint">
            No ID yet? Leave it blank and use the mobile you <a href="/join">registered</a> with.
          </p>
        )}
      </div>
      <div className="field" data-invalid={invalid("name")}>
        <label htmlFor="m-name">Full name</label>
        <input id="m-name" name="name" type="text" autoComplete="name" placeholder="Your name" maxLength={80} />
        {fieldErr("name")}
      </div>
      <div className="mo-two">
        <div className="field" data-invalid={invalid("phone")}>
          <label htmlFor="m-phone">Mobile</label>
          <input id="m-phone" name="phone" type="tel" inputMode="tel" autoComplete="tel" placeholder="0412 345 678" />
          {fieldErr("phone")}
        </div>
        <div className="field">
          <label htmlFor="m-ig">
            Instagram <em>optional</em>
          </label>
          <input id="m-ig" name="instagram" type="text" placeholder="@yourhandle" autoCapitalize="off" autoCorrect="off" />
        </div>
      </div>
      <div className="field" data-invalid={invalid("email")}>
        <label htmlFor="m-email">
          Email <em>for the preview and digital file</em>
        </label>
        <input id="m-email" name="email" type="email" autoComplete="email" placeholder="you@example.com" />
        {fieldErr("email")}
      </div>

      <div className="field" data-invalid={invalid("delivery")}>
        <span className="label">Delivery</span>
        <div className="open-seg mo-seg">
          <label>
            <input type="radio" name="delivery" value="pickup" defaultChecked />
            <span>Pick up at a meet</span>
          </label>
          <label>
            <input type="radio" name="delivery" value="post" />
            <span>Post it (postage extra)</span>
          </label>
        </div>
        {fieldErr("delivery")}
      </div>
      <div className="field">
        <label htmlFor="m-notes">
          Anything else? <em>optional</em>
        </label>
        <textarea id="m-notes" name="notes" rows={2} maxLength={400} placeholder="Text for the artwork (e.g. OPA!), a gift for someone…" />
      </div>

      <div className="hp" aria-hidden>
        <label>
          Company <input name="company" type="text" tabIndex={-1} autoComplete="off" />
        </label>
      </div>
      <label className="check">
        <input type="checkbox" name="consent" />
        <span>
          I&apos;m 18+ (or a parent ordering), and 88 Risers can turn my event photos into this artwork.
          {err?.field === "consent" ? <span className="field-error" style={{ display: "block" }}>{err.message}</span> : null}
        </span>
      </label>

      <div className="mo-total">
        <span>Total</span>
        <b>${total}</b>
      </div>
      <button className="btn btn-primary submit" type="submit" disabled={pending || !picked.length}>
        {pending ? "Sending…" : "Order my moment"} {!pending ? <Arrow /> : null}
      </button>
      <p className="fine">
        Nothing to pay now. We send a preview first; you pay once you approve it. Every order includes the high-res digital
        artwork. Printed pieces take about 2–3 weeks.
      </p>
    </form>
  );
}
