"use client";

import { startTransition, useActionState, useState } from "react";
import { orderMoments, type MomentState } from "@/app/(site)/moments/actions";
import { MOMENTS_BASE, MOMENTS_DEPOSIT, MOMENTS_FULL_SET, MOMENTS_ITEMS_SUM, MOMENT_EVENTS, MOMENT_ITEMS, SHIRT_SIZES, momentsTotal } from "@/lib/momentsConfig";
import { SITE } from "@/lib/site";
import { Arrow, Check, Instagram } from "./Icons";

/** 88 Moments order: pick the event and moment, choose pieces, see the total. Pay later. */
export function MomentsForm() {
  const [state, action, pending] = useActionState<MomentState, FormData>(orderMoments, { status: "idle" });
  const [picked, setPicked] = useState<string[]>([]);
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
          <h3>Almost booked{state.name ? `, ${state.name}` : ""}</h3>
          <p>
            {state.count ? `Booking + ${state.count} ${state.count === 1 ? "piece" : "pieces"}` : "Booking + digital artwork"} · <b>${state.total}</b>. Pay the <b>${state.deposit} deposit</b> to
            lock in the camera for your comp. It&apos;s non-refundable and comes off your total, so the balance after you approve
            your artwork is <b>${Math.max(0, state.total - state.deposit)}</b>.
          </p>
          <a className="btn btn-primary submit" href={`/pay/moment/${state.id}`} target="_blank" rel="noreferrer">
            Pay ${state.deposit} deposit <Arrow />
          </a>
          <p className="fine">Booking #{state.id}. Card or PayPal, through PayPal. Your booking is confirmed once the deposit arrives.</p>
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
        <h3>Book</h3>
        <span>${MOMENTS_DEPOSIT} deposit holds your spot</span>
      </div>
      {err && !err.field ? (
        <div className="form-error" role="alert">
          {err.message}
        </div>
      ) : null}

      <div className="field" data-invalid={invalid("items")}>
        <span className="label">Your moment</span>
        <div className="mo-items">
          <label className="on mo-base">
            <input type="checkbox" checked disabled readOnly />
            <span className="mo-item-name">
              Moment booking
              <small>Camera on you at the comp, your sumi-e artwork, high-res digital file</small>
            </span>
            <b>${MOMENTS_BASE}</b>
          </label>
        </div>
        <span className="label" style={{ marginTop: 14 }}>
          Add printed pieces <em>optional</em>
        </span>
        <div className="mo-items">
          {MOMENT_ITEMS.map((i) => (
            <label key={i.id} className={picked.includes(i.id) ? "on" : undefined}>
              <input type="checkbox" name="items" value={i.id} checked={picked.includes(i.id)} onChange={() => toggle(i.id)} />
              <span className="mo-item-name">{i.name}</span>
              <b>+${i.price}</b>
            </label>
          ))}
        </div>
        <button type="button" className="mo-all" onClick={() => setPicked(all ? [] : MOMENT_ITEMS.map((i) => i.id))}>
          {all ? "Just the booking and digital artwork" : `Full Risers Moment Package · $${MOMENTS_FULL_SET} (save $${MOMENTS_ITEMS_SUM - MOMENTS_FULL_SET})`}
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
        <label htmlFor="m-event">Which comp should we shoot you at?</label>
        <select id="m-event" name="event" value={event} onChange={(e) => setEvent(e.target.value)}>
          <option value="" disabled>
            Pick the event
          </option>
          {MOMENT_EVENTS.map((ev) => (
            <option key={ev}>{ev}</option>
          ))}
        </select>
        {event === "Other event" ? <input name="event_other" type="text" placeholder="Event name and date" maxLength={120} style={{ marginTop: 8 }} /> : null}
        {fieldErr("event")}
      </div>
      <div className="field" data-invalid={invalid("moment")}>
        <label htmlFor="m-moment">Help us find you</label>
        <textarea
          id="m-moment"
          name="moment"
          rows={3}
          maxLength={600}
          placeholder="Division and arm(s), what you'll be wearing, anything you want captured (the walk-out, your roar, a rival)…"
        />
        {fieldErr("moment") ?? <p className="field-hint">On the day the camera follows you: warm-up, every match, the result.</p>}
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
          I&apos;m 18+ (or a parent ordering), 88 Risers can turn my event photos into this artwork, and I understand the $
          {MOMENTS_DEPOSIT} deposit is non-refundable.
          {err?.field === "consent" ? <span className="field-error" style={{ display: "block" }}>{err.message}</span> : null}
        </span>
      </label>

      <div className="mo-total">
        <span>Total</span>
        <b>${total}</b>
      </div>
      <button className="btn btn-primary submit" type="submit" disabled={pending}>
        {pending ? "Booking…" : `Book · $${MOMENTS_DEPOSIT} deposit`} {!pending ? <Arrow /> : null}
      </button>
      <p className="fine">
        Book now and pay a ${MOMENTS_DEPOSIT} non-refundable deposit to hold the camera for you; it comes off your total. We shoot you
        at the comp, send a preview, and you pay the balance once you approve it. Every booking includes the high-res digital
        artwork. Printed pieces take about 2–3 weeks. Postage is extra; pick up at a meet is free.
      </p>
    </form>
  );
}
