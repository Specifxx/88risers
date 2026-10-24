import type { Metadata } from "next";
import Link from "next/link";
import { ShopGrid } from "@/components/ShopGrid";
import { PRODUCTS } from "@/lib/shop";

export const metadata: Metadata = {
  title: "Shop",
  description: "Concept 88 Risers gear: club tees, customised competition jerseys, grip handles and more. Register interest for the first drop.",
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
            Rep the <span className="gold-text">table.</span>
          </h1>
          <p className="lede">
            Club tees, customised competition jerseys and training gear. The shop isn&apos;t open yet: these are
            concepts, and prices may change. Register interest with your name and number and we&apos;ll text you when the first drop lands.
          </p>
          <p className="shop-note">
            <span>Concept shop</span> No orders or payments are taken on this page.
          </p>
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
