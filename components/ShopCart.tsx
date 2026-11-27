"use client";

import { useEffect, useState, useTransition } from "react";
import { checkCode, startCheckout } from "@/app/(site)/shop/actions";
import { type CartLine, type Product, PRODUCTS, SIZES, SLEEVES, lineLabel, money, shippingFor } from "@/lib/shop";
import { Arrow } from "./Icons";

const STATES = ["NSW", "VIC", "QLD", "WA", "SA", "TAS", "ACT", "NT"];
const priceOf = (l: CartLine) => PRODUCTS.find((p) => p.id === l.product)?.buy?.price ?? 0;

/** Options for one item (size, sleeve, personalisation, quantity) before it goes in the cart. */
export function AddToCart({ product, onAdd }: { product: Product; onAdd: (l: CartLine) => void }) {
  const [size, setSize] = useState("");
  const [sleeve, setSleeve] = useState<string>("Raglan");
  const [qty, setQty] = useState(1);
  const [name, setName] = useState("");
  const [nickname, setNickname] = useState("");
  const [riserNo, setRiserNo] = useState("");
  const [err, setErr] = useState<string | null>(null);
  const personalise = !!product.buy?.personalise;
  return (
    <form
      className="form-card add-to-cart"
      onSubmit={(e) => {
        e.preventDefault();
        if (!size) return setErr("Pick a size.");
        if (personalise && !name.trim()) return setErr("Add the name for the back.");
        if (riserNo && !/^#?\d{1,3}$/.test(riserNo.trim())) return setErr("Riser numbers are up to 3 digits, like 017.");
        onAdd({
          product: product.id,
          size,
          sleeve,
          qty,
          ...(personalise ? { name: name.trim().toUpperCase(), nickname: nickname.trim(), riserNo: riserNo.trim().replace(/^#/, "") } : {}),
        });
      }}
    >
      <div className="form-title">
        <h3>{product.name}</h3>
        <span>{money(product.buy?.price ?? 0)}</span>
      </div>
      <div className="field">
        <span className="label">Size</span>
        <div className="open-seg size-seg">
          {SIZES.map((z) => (
            <label key={z}>
              <input type="radio" name="size" value={z} checked={size === z} onChange={() => setSize(z)} />
              <span>{z}</span>
            </label>
          ))}
        </div>
      </div>
      <div className="field">
        <span className="label">Sleeve</span>
        <div className="open-seg mo-seg">
          {SLEEVES.map((s) => (
            <label key={s}>
              <input type="radio" name="sleeve" value={s} checked={sleeve === s} onChange={() => setSleeve(s)} />
              <span>{s} sleeve</span>
            </label>
          ))}
        </div>
      </div>
      {personalise ? (
        <>
          <div className="field">
            <label htmlFor="c-name">Name on the back</label>
            <input id="c-name" type="text" value={name} onChange={(e) => setName(e.target.value)} maxLength={20} placeholder="e.g. HARRY LU" />
          </div>
          <div className="mo-two">
            <div className="field">
              <label htmlFor="c-nick">
                Nickname <em>optional</em>
              </label>
              <input id="c-nick" type="text" value={nickname} onChange={(e) => setNickname(e.target.value)} maxLength={20} placeholder="e.g. The Penguin" />
            </div>
            <div className="field">
              <label htmlFor="c-no">
                Riser no. <em>optional</em>
              </label>
              <input id="c-no" type="text" inputMode="numeric" value={riserNo} onChange={(e) => setRiserNo(e.target.value)} maxLength={4} placeholder="e.g. 001" />
            </div>
          </div>
        </>
      ) : null}
      <div className="field">
        <label htmlFor="c-qty">Quantity</label>
        <select id="c-qty" value={qty} onChange={(e) => setQty(Number(e.target.value))}>
          {Array.from({ length: 10 }, (_, i) => i + 1).map((n) => (
            <option key={n} value={n}>
              {n}
            </option>
          ))}
        </select>
      </div>
      {err ? <p className="field-error">{err}</p> : null}
      <button className="btn btn-primary submit" type="submit">
        Add to cart · {money((product.buy?.price ?? 0) * qty)}
      </button>
    </form>
  );
}

/** The cart and checkout: delivery, contact details, then off to PayPal. */
export function Checkout({ lines, setLines }: { lines: CartLine[]; setLines: (l: CartLine[]) => void }) {
  const [delivery, setDelivery] = useState<"pickup" | "post">("pickup");
  const [msg, setMsg] = useState<string | null>(null);
  const [pending, start] = useTransition();
  const [codeInput, setCodeInput] = useState("");
  const [code, setCode] = useState<{ code: string; percent: number } | null>(null);
  const [codeMsg, setCodeMsg] = useState<string | null>(null);
  const count = lines.reduce((n, l) => n + l.qty, 0);
  const subtotal = lines.reduce((n, l) => n + priceOf(l) * l.qty, 0);
  const discount = code ? Math.round(subtotal * code.percent) / 100 : 0;
  const ship = delivery === "post" ? shippingFor(count) : { label: "Pickup at a meet", price: 0 };
  const total = Math.round((subtotal - discount + ship.price) * 100) / 100;

  const apply = (raw: string) =>
    start(async () => {
      const r = await checkCode(raw);
      if (r.ok) {
        setCode({ code: r.code, percent: r.percent });
        setCodeInput(r.code);
        setCodeMsg(null);
        try {
          localStorage.setItem("88ref", r.code);
        } catch {}
      } else {
        setCode(null);
        setCodeMsg(r.message);
      }
    });

  // A shared link like /shop?ref=HARRY fills the code in (and it's remembered on this device).
  useEffect(() => {
    let ref = "";
    try {
      ref = new URLSearchParams(window.location.search).get("ref") || localStorage.getItem("88ref") || "";
    } catch {}
    if (ref) {
      setCodeInput(ref.toUpperCase());
      apply(ref);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (!lines.length) return null;
  return (
    <section className="cart" id="cart" aria-label="Your cart">
      <form
        className="form-card cart-card"
        onSubmit={(e) => {
          e.preventDefault();
          const f = new FormData(e.currentTarget);
          const s = (k: string) => String(f.get(k) ?? "");
          setMsg(null);
          start(async () => {
            const r = await startCheckout({
              lines,
              name: s("name"),
              email: s("email"),
              phone: s("phone"),
              delivery,
              address: { line1: s("line1"), line2: s("line2"), suburb: s("suburb"), state: s("state"), postcode: s("postcode") },
              notes: s("notes"),
              code: code?.code,
            });
            if (!r.ok) return setMsg(r.message);
            try {
              localStorage.removeItem("88cart");
            } catch {}
            window.location.href = r.url;
          });
        }}
      >
        <div className="form-title">
          <h3>Your cart</h3>
          <span>
            {count} item{count === 1 ? "" : "s"}
          </span>
        </div>
        <ul className="cart-lines">
          {lines.map((l, i) => (
            <li key={i}>
              <span>
                <b>{l.qty} ×</b> {lineLabel(l)}
              </span>
              <span className="cart-price">{money(priceOf(l) * l.qty)}</span>
              <button type="button" className="cart-x" aria-label="Remove" onClick={() => setLines(lines.filter((_, j) => j !== i))}>
                ×
              </button>
            </li>
          ))}
        </ul>

        <div className="field">
          <span className="label">Delivery</span>
          <div className="open-seg mo-seg">
            <label>
              <input type="radio" name="delivery" checked={delivery === "pickup"} onChange={() => setDelivery("pickup")} />
              <span>Pickup at a meet · free</span>
            </label>
            <label>
              <input type="radio" name="delivery" checked={delivery === "post"} onChange={() => setDelivery("post")} />
              <span>Post · {money(shippingFor(count).price)}</span>
            </label>
          </div>
          {delivery === "post" ? <p className="field-hint">{shippingFor(count).label}, tracked, anywhere in Australia. Posted from Doonside NSW.</p> : null}
        </div>
        {delivery === "post" ? (
          <>
            <div className="field">
              <label htmlFor="k-l1">Street address</label>
              <input id="k-l1" name="line1" type="text" autoComplete="address-line1" maxLength={100} />
            </div>
            <div className="field">
              <label htmlFor="k-l2">
                Apartment, unit <em>optional</em>
              </label>
              <input id="k-l2" name="line2" type="text" autoComplete="address-line2" maxLength={100} />
            </div>
            <div className="cart-addr">
              <div className="field">
                <label htmlFor="k-sub">Suburb</label>
                <input id="k-sub" name="suburb" type="text" autoComplete="address-level2" maxLength={60} />
              </div>
              <div className="field">
                <label htmlFor="k-st">State</label>
                <select id="k-st" name="state" defaultValue="NSW" autoComplete="address-level1">
                  {STATES.map((s) => (
                    <option key={s}>{s}</option>
                  ))}
                </select>
              </div>
              <div className="field">
                <label htmlFor="k-pc">Postcode</label>
                <input id="k-pc" name="postcode" type="text" inputMode="numeric" autoComplete="postal-code" maxLength={4} />
              </div>
            </div>
          </>
        ) : null}

        <div className="field">
          <label htmlFor="k-name">Full name</label>
          <input id="k-name" name="name" type="text" autoComplete="name" maxLength={80} />
        </div>
        <div className="mo-two">
          <div className="field">
            <label htmlFor="k-email">Email (for your receipt)</label>
            <input id="k-email" name="email" type="email" autoComplete="email" maxLength={120} />
          </div>
          <div className="field">
            <label htmlFor="k-phone">Mobile</label>
            <input id="k-phone" name="phone" type="tel" inputMode="tel" autoComplete="tel" placeholder="0412 345 678" />
          </div>
        </div>
        <div className="field">
          <label htmlFor="k-notes">
            Notes <em>optional</em>
          </label>
          <input id="k-notes" name="notes" type="text" maxLength={300} placeholder="Anything we should know" />
        </div>

        <div className="field">
          <label htmlFor="k-code">
            Affiliate code <em>optional</em>
          </label>
          <div className="code-row">
            <input
              id="k-code"
              type="text"
              value={codeInput}
              onChange={(e) => {
                setCodeInput(e.target.value.toUpperCase());
                if (code) setCode(null);
              }}
              placeholder="e.g. HARRY"
              maxLength={15}
              autoCapitalize="characters"
            />
            <button type="button" className="btn btn-sm btn-ghost" onClick={() => apply(codeInput)} disabled={pending || !codeInput.trim()}>
              Apply
            </button>
          </div>
          {code ? <p className="field-hint code-ok">{code.code} applied: {code.percent}% off your items.</p> : codeMsg ? <p className="field-error">{codeMsg}</p> : null}
        </div>

        <div className="cart-sum">
          <span>Subtotal</span>
          <b>{money(subtotal)}</b>
          {code ? (
            <>
              <span>Code {code.code}</span>
              <b>−{money(discount)}</b>
            </>
          ) : null}
          <span>{delivery === "post" ? "Postage" : "Pickup"}</span>
          <b>{ship.price ? money(ship.price) : "Free"}</b>
          <span className="cart-total">Total</span>
          <b className="cart-total">{money(total)} AUD</b>
        </div>
        {msg ? (
          <div className="form-error" role="alert">
            {msg}
          </div>
        ) : null}
        <button className="btn btn-primary submit" type="submit" disabled={pending}>
          {pending ? "Opening PayPal…" : `Pay ${money(total)} with PayPal`} {!pending ? <Arrow /> : null}
        </button>
        <p className="fine">
          Pay by card or PayPal account. Your receipt is emailed from 88risers@gmail.com once the payment goes through. By paying you agree to our{" "}
          <a href="/terms#shop">Terms &amp; Refunds</a> (no change-of-mind returns, so check your size) and{" "}
          <a href="/privacy">Privacy policy</a>.
        </p>
      </form>
    </section>
  );
}
