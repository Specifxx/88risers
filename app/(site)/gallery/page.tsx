import type { Metadata } from "next";
import Link from "next/link";
import { Gallery, type GalleryItem } from "@/components/Gallery";

export const metadata: Metadata = {
  title: "Gallery",
  description: "Stylised 88 Risers concept art: the guardian lion, red ink and gold cloud work, imagined on tees, the gym wall and grip gear.",
};

const GALLERY: GalleryItem[][] = [
  [
    { src: "/gallery/crest-lion.jpg", w: 781, h: 609, title: "Lion crest", note: "Stylised artwork" },
    { src: "/gallery/logo.jpg", w: 359, h: 461, title: "Symbol study", note: "Stylised artwork" },
    { src: "/gallery/lion.jpg", w: 381, h: 461, title: "Guardian lion", note: "Stylised artwork" },
  ],
  [
    { src: "/gallery/tee.jpg", w: 532, h: 406, title: "Club tee", note: "Apparel concept" },
    { src: "/gallery/mural.jpg", w: 494, h: 406, title: "Gym wall", note: "Mural concept" },
  ],
  [
    { src: "/gallery/grip.jpg", w: 494, h: 211, title: "Grip wrap", note: "Gear concept" },
    { src: "/gallery/patch.jpg", w: 494, h: 189, title: "Woven patch", note: "Gear concept" },
  ],
  [{ src: "/gallery/elements.jpg", w: 745, h: 131, title: "Art elements", note: "Circle · Om · Cloud · Lion" }],
];
const GALLERY_BOARD: GalleryItem = {
  src: "/gallery/board.jpg",
  w: 1536,
  h: 1024,
  title: "Concept board",
  note: "Stylised artwork",
};

export default function GalleryPage() {
  return (
    <>
      <section className="page-hero">
        <div className="wrap">
          <p className="crumbs">
            <Link href="/">Home</Link> / Gallery
          </p>
          <h1 className="display">
            Forged in <span className="gold-text">gold.</span>
          </h1>
          <p className="lede">
            Stylised concept art inspired by the 88 Risers logo: the guardian lion, red ink and gold cloud work,
            imagined on tees, the gym wall and grip gear. Tap any piece to see it up close.
          </p>
        </div>
      </section>

      <section className="section gallery-section" style={{ paddingTop: 60 }}>
        <div className="wrap">
          <Gallery rows={GALLERY} board={GALLERY_BOARD} />
        </div>
      </section>
    </>
  );
}
