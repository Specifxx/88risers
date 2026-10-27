import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { InstallApp } from "@/components/InstallApp";

export const metadata: Metadata = {
  title: "Get the app",
  description: "Put 88 Risers on your phone's home screen: events, supermatches, Pin Run and your training log, one tap away.",
};

export default function AppPage() {
  return (
    <>
      <section className="page-hero" style={{ paddingBottom: 16 }}>
        <div className="wrap app-hero">
          <Image src="/icons/icon-192.png" alt="" width={96} height={96} className="app-icon" />
          <div>
            <p className="crumbs">
              <Link href="/">Home</Link> / Get the app
            </p>
            <h1 className="display">
              88 Risers <span className="gold-text">app.</span>
            </h1>
            <p className="lede">
              Put the club on your home screen. It opens full screen like any other app, with Pin Run, Katana Draw, supermatch picks, your
              coins and your training log one tap away. It&apos;s free, takes seconds, and always has the latest version.
            </p>
          </div>
        </div>
      </section>
      <section className="section" style={{ paddingTop: 8 }}>
        <div className="wrap">
          <InstallApp />
        </div>
      </section>
    </>
  );
}
