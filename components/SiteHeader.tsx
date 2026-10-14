"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { Menu } from "./Icons";

const NAV = [
  { href: "/#club", label: "Club" },
  { href: "/events", label: "Events" },
  { href: "/pullers", label: "Database" },
  { href: "/#founders", label: "Founders" },
];

export function SiteHeader() {
  const path = usePathname();
  const [scrolled, setScrolled] = useState(false);
  const menu = useRef<HTMLDetailsElement>(null);

  useEffect(() => {
    const on = () => setScrolled(window.scrollY > 24);
    on();
    window.addEventListener("scroll", on, { passive: true });
    return () => window.removeEventListener("scroll", on);
  }, []);

  useEffect(() => {
    menu.current?.removeAttribute("open");
  }, [path]);

  return (
    <header className="site-header" data-scrolled={scrolled || path !== "/"}>
      <div className="wrap">
        <Link href="/" className="brand" aria-label="88 Risers home">
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src="/crest.jpg" alt="" width={42} height={42} />
          <span>
            <b>88 Risers</b>
            <small>Arm Wrestling Club</small>
          </span>
        </Link>
        <nav className="nav" aria-label="Main">
          {NAV.map((n) => (
            <Link key={n.href} href={n.href} aria-current={path.startsWith(n.href) && !n.href.includes("#") ? "page" : undefined}>
              {n.label}
            </Link>
          ))}
        </nav>
        <Link href="/join" className="btn btn-primary header-cta">
          Join
        </Link>
        <details className="menu" ref={menu}>
          <summary aria-label="Menu">
            <Menu />
          </summary>
          <div className="menu-panel">
            {NAV.map((n, i) => (
              <Link key={n.href} href={n.href} onClick={() => menu.current?.removeAttribute("open")}>
                {n.label} <span>0{i + 1}</span>
              </Link>
            ))}
            <a href="https://www.instagram.com/88risers_/" target="_blank" rel="noreferrer">
              Instagram <span>↗</span>
            </a>
          </div>
        </details>
      </div>
    </header>
  );
}
