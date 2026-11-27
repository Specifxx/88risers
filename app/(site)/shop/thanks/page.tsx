import type { Metadata } from "next";
import Link from "next/link";
import { lineLabel, money, PRODUCTS } from "@/lib/shop";
import { dollars, getShopOrder, orderLines } from "@/lib/shopOrders";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Order", robots: { index: false } };

/** Where PayPal sends buyers back: the order and whether the payment has come through yet. */
export default async function ThanksPage({ searchParams }: PageProps<"/shop/thanks">) {
  const sp = await searchParams;
  const id = Number(sp.o);
  const token = typeof sp.t === "string" ? sp.t : "";
  const o = Number.isInteger(id) && token ? await getShopOrder(id, token) : null;
  const paid = o && o.status !== "pending" && o.status !== "cancelled";
  return (
    <section className="page-hero" style={{ minHeight: "70vh" }}>
      <div className="wrap" style={{ maxWidth: 680 }}>
        <p className="crumbs">
          <Link href="/shop">Shop</Link> / Order
        </p>
        {!o ? (
          <>
            <h1 className="display">Order not found</h1>
            <p className="lede">
              Check the link, or DM us on Instagram with your name and we&apos;ll sort it out. <Link href="/shop">Back to the shop</Link>
            </p>
          </>
        ) : (
          <>
            <h1 className="display">
              {paid ? (
                <>
                  Thanks, <span className="gold-text">{o.name.split(" ")[0]}.</span>
                </>
              ) : (
                <>
                  Almost <span className="gold-text">there.</span>
                </>
              )}
            </h1>
            <p className="lede">
              {paid
                ? `Order #${o.id} is paid. Your receipt is on its way to ${o.email} from 88risers@gmail.com.`
                : `Order #${o.id} is waiting for PayPal to confirm your payment. That usually takes a few seconds: refresh this page. If you didn't finish paying, go back to the shop and check out again.`}
            </p>
            <div className="panel" style={{ marginTop: 24 }}>
              <ul className="cart-lines">
                {orderLines(o).map((l, i) => (
                  <li key={i}>
                    <span>
                      <b>{l.qty} ×</b> {lineLabel(l)}
                    </span>
                    <span className="cart-price">{money((PRODUCTS.find((p) => p.id === l.product)?.buy?.price ?? 0) * l.qty)}</span>
                    <span />
                  </li>
                ))}
              </ul>
              <div className="cart-sum">
                {o.discount_cents ? (
                  <>
                    <span>Code {o.promo_code}</span>
                    <b>−{dollars(o.discount_cents)}</b>
                  </>
                ) : null}
                <span>{o.delivery === "post" ? o.shipping_label || "Postage" : "Pickup at a meet"}</span>
                <b>{o.shipping_cents ? dollars(o.shipping_cents) : "Free"}</b>
                <span className="cart-total">Total</span>
                <b className="cart-total">{dollars(o.total_cents)} AUD</b>
              </div>
              <p className="muted" style={{ margin: 0, whiteSpace: "pre-line" }}>
                {o.delivery === "post" ? `Posting to:\n${o.name}\n${o.address}` : "Pick it up at the next 88 Risers meet. We'll text you when it's ready."}
              </p>
            </div>
            <p className="fine" style={{ marginTop: 18 }}>
              Questions? Email 88risers@gmail.com or DM @88risers_ on Instagram with order #{o.id}.
            </p>
          </>
        )}
      </div>
    </section>
  );
}
