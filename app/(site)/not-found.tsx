import Link from "next/link";

export default function NotFound() {
  return (
    <section className="page-hero" style={{ minHeight: "70vh", display: "flex", alignItems: "center" }}>
      <div className="wrap">
        <p className="eyebrow">404 · Foul</p>
        <h1 className="display">
          Slipped <span className="gold-text">grip.</span>
        </h1>
        <p className="lede">That page doesn&apos;t exist. Reset and go again.</p>
        <div className="btn-row" style={{ marginTop: 28 }}>
          <Link className="btn btn-primary" href="/">
            Back to the table
          </Link>
          <Link className="btn" href="/pullers">
            Riser Database
          </Link>
        </div>
      </div>
    </section>
  );
}
