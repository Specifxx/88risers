/**
 * Shown the instant a link is clicked while a database-backed page (supermatch, rewards,
 * play, account…) renders on the server. Next prefetches it, so clicks never feel stuck.
 */
export default function Loading() {
  return (
    <section className="page-hero page-loading" aria-busy="true" aria-label="Loading">
      <div className="wrap">
        <span className="sk sk-crumbs" />
        <span className="sk sk-title" />
        <span className="sk sk-title sk-short" />
        <span className="sk sk-lede" />
        <span className="sk sk-lede sk-short" />
        <div className="sk-cards">
          <span className="sk sk-card" />
          <span className="sk sk-card" />
          <span className="sk sk-card" />
        </div>
      </div>
    </section>
  );
}
