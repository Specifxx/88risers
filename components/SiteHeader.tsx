"use client";

import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { Menu } from "./Icons";

/** Desktop bar: the main destinations. */
const NAV = [
  { href: "/events", label: "Events" },
  { href: "/pullers", label: "Database" },
  { href: "/chalk", label: "Chalk" },
  { href: "/supermatch", label: "Supermatch" },
  { href: "/play", label: "Play" },
  { href: "/tv", label: "TV" },
  { href: "/gallery", label: "Gallery" },
  { href: "/shop", label: "Shop" },
];
/** Phone menu: everything. */
const MENU = [
  { href: "/#club", label: "Club" },
  ...NAV.slice(0, 3),
  { href: "/#founders", label: "Founders" },
  ...NAV.slice(3),
  { href: "/rewards", label: "Rewards" },
  { href: "/account", label: "Account" },
  { href: "/log", label: "Training log" },
  { href: "/app", label: "Get the app" },
];

export function SiteHeader() {
  const path = usePathname();
  const [scrolled, setScrolled] = useState(false);
  const signedIn = useSignedIn(path);
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

  // Clicking the link for the page you're already on scrolls back to the top.
  const toTop = (href: string) => (e: React.MouseEvent) => {
    if (href === path && !e.metaKey && !e.ctrlKey && !e.shiftKey) {
      e.preventDefault();
      window.scrollTo({ top: 0, behavior: "smooth" });
    }
  };

  return (
    <header className="site-header" data-scrolled={scrolled || path !== "/"}>
      <div className="wrap">
        <Link href="/" className="brand" aria-label="88 Risers home" onClick={toTop("/")}>
          <Image src="/crest.jpg" alt="" width={42} height={42} priority />
          <span>
            <b>88 Risers</b>
            <small>Arm Wrestling Club</small>
          </span>
        </Link>
        <nav className="nav" aria-label="Main">
          {NAV.map((n) => (
            <Link key={n.href} href={n.href} onClick={toTop(n.href)} aria-current={path.startsWith(n.href) && !n.href.includes("#") ? "page" : undefined}>
              {n.label}
            </Link>
          ))}
        </nav>
        <Link
          href="/account"
          className="header-acct"
          aria-label={signedIn ? "Your account and coins" : "Sign up: make a free account for coins, games and picks"}
          title={signedIn ? "Your account and coins" : "Make a free account: coins, games, picks"}
          aria-current={path.startsWith("/account") ? "page" : undefined}
        >
          <span className="acct-ball" aria-hidden />
          <span className="acct-label">{signedIn ? "Account" : "Sign up"}</span>
        </Link>
        <Link href="/join" className="btn btn-primary header-cta" title="Register to join the club as a Riser (get your Riser ID)">
          <span className="cta-long">Become a Riser</span>
          <span className="cta-short">Be a Riser</span>
        </Link>
        <details className="menu" ref={menu}>
          <summary aria-label="Menu">
            <Menu />
          </summary>
          <div className="menu-panel">
            {MENU.map((n, i) => (
              <Link key={n.href} href={n.href} onClick={() => menu.current?.removeAttribute("open")}>
                {n.label} <span>{String(i + 1).padStart(2, "0")}</span>
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

/**
 * Whether this browser is logged in, without making pages dynamic: a readable hint cookie set at
 * login, or (for older sessions) one check with the server per visit.
 */
function useSignedIn(path: string) {
  const [signedIn, setSignedIn] = useState(false);
  useEffect(() => {
    const hinted = document.cookie.split("; ").some((c) => c === "88r_in=1");
    setSignedIn(hinted);
    if (hinted) return;
    let asked = false;
    try {
      asked = sessionStorage.getItem("88r_whoami") === "1";
    } catch {}
    if (asked) return;
    fetch("/api/whoami", { cache: "no-store" })
      .then((r) => r.json())
      .then((r: { in: boolean }) => {
        try {
          sessionStorage.setItem("88r_whoami", "1");
        } catch {}
        if (r.in) {
          document.cookie = "88r_in=1; path=/; max-age=2592000; samesite=lax";
          setSignedIn(true);
        }
      })
      .catch(() => {});
  }, [path]);
  return signedIn;
}
