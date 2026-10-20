import Image from "next/image";
import Link from "next/link";
import { SITE } from "@/lib/site";

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="wrap">
        <div className="footer-grid">
          <div className="footer-brand">
            <Image src="/crest.jpg" alt="88 Risers crest" width={96} height={96} />
            <p>
              A social arm wrestling club in Rhodes, Sydney. Associated with the {SITE.federation}. Strength in the grip,
              respect at the table.
            </p>
          </div>
          <div>
            <h4>Club</h4>
            <ul>
              <li><Link href="/join">Register</Link></li>
              <li><Link href="/events">Events</Link></li>
              <li><Link href="/#table-time">Table time</Link></li>
              <li><Link href="/#faq">FAQ</Link></li>
            </ul>
          </div>
          <div>
            <h4>Database</h4>
            <ul>
              <li><Link href="/pullers">Riser Database</Link></li>
              <li><Link href="/pullers#leaderboard">Leaderboard</Link></li>
              <li><Link href="/#founders">Founders</Link></li>
              <li><Link href="/tv">88RisersTV</Link></li>
              <li><Link href="/gallery">Gallery</Link></li>
              <li><Link href="/shop">Shop</Link></li>
            </ul>
          </div>
          <div>
            <h4>Connect</h4>
            <ul>
              <li><a href={SITE.instagramUrl} target="_blank" rel="noreferrer">@{SITE.instagramHandle}</a></li>
              <li><a href={`mailto:${SITE.email}`}>{SITE.email}</a></li>
              <li><a href={SITE.training.mapsUrl} target="_blank" rel="noreferrer">{SITE.training.venue}</a></li>
            </ul>
          </div>
        </div>
        <div className="footer-wordmark" aria-hidden>
          88 Risers
        </div>
        <div className="footer-base">
          <span>© {new Date().getFullYear()} 88 Risers Arm Wrestling Club</span>
          <span>Rhodes · NSW · Australia</span>
        </div>
      </div>
    </footer>
  );
}
