import type { Metadata } from "next";
import Link from "next/link";
import { ShopGrid } from "@/components/ShopGrid";
import { PRODUCTS } from "@/lib/shop";

export const metadata: Metadata = {
  title: "Shop",
  description: "88 Risers gear: the Club Compression Tee and the customised Competition Jersey (raglan or flat sleeve). Pickup at a meet or posted Australia-wide.",
};

export default function ShopPage() {
  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / Shop
          </p>
          <h1 className="display">
            Rep <span className="gold-text">88Risers.</span>
          </h1>
          <Link href="/support#sponsor" className="btn btn-sm btn-ghost shop-sponsor-link">
            Put your brand on our jerseys: become a sponsor →
          </Link>
        </div>
      </section>

      <section className="section" style={{ paddingTop: 60 }}>
        <div className="wrap">
          <ShopGrid products={PRODUCTS} />
          <aside className="shop-sponsor">
            <div>
              <p className="eyebrow">Sponsor the kit</p>
              <h2 className="display">
                Your logo, <span className="gold-text">on every Riser.</span>
              </h2>
              <p className="muted">
                Sponsors get their brand on club shirts and jerseys, a spot on the site, and shout-outs at meets and on
                Instagram. Products as prizes count too.
              </p>
            </div>
            <div className="shop-sponsor-cta">
              <Link href="/support#sponsor" className="btn btn-primary">
                Become a sponsor
              </Link>
              <Link href="/support#donate" className="btn btn-ghost">
                Or donate to club funds
              </Link>
            </div>
          </aside>
        </div>
      </section>
    </>
  );
}
