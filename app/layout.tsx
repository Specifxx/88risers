import type { Metadata, Viewport } from "next";
import { Chakra_Petch, Inter, Saira_Extra_Condensed } from "next/font/google";
import { SiteAnalytics } from "@/components/SiteAnalytics";
import { SITE } from "@/lib/site";
import "./globals.css";

const display = Saira_Extra_Condensed({
  subsets: ["latin"],
  weight: ["600", "800", "900"],
  variable: "--f-display",
  display: "swap",
});
const tech = Chakra_Petch({ subsets: ["latin"], weight: ["500", "600", "700"], variable: "--f-tech", display: "swap" });
const body = Inter({ subsets: ["latin"], variable: "--f-body", display: "swap" });

const description =
  "88 Risers is a social arm wrestling club in Rhodes, Sydney. We meet the first Sunday of every month. Register, claim your permanent Riser ID, and win a cased champion card of yourself.";

export const metadata: Metadata = {
  metadataBase: new URL(SITE.url),
  title: { default: "88 Risers — Arm Wrestling Club, Rhodes NSW", template: "%s · 88 Risers" },
  description,
  openGraph: {
    title: "88 Risers — We're looking for the 88th Riser",
    description,
    type: "website",
    locale: "en_AU",
    siteName: "88 Risers",
  },
  twitter: { card: "summary_large_image" },
};

export const viewport: Viewport = {
  themeColor: "#0a0908",
  colorScheme: "dark",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en-AU" data-scroll-behavior="smooth" suppressHydrationWarning className={`${display.variable} ${tech.variable} ${body.variable}`}>
      <body>
        {children}
        <SiteAnalytics />
      </body>
    </html>
  );
}
