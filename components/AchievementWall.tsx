import { ACHIEVEMENTS } from "@/lib/achievements";

/** Earned trophies lit up, locked ones dimmed with how to get them. */
export function AchievementWall({ earned, title = "Achievements" }: { earned: Set<string>; title?: string }) {
  return (
    <div className="panel">
      <h2 className="panel-title">
        {title}
        <small>
          {earned.size}/{ACHIEVEMENTS.length}
        </small>
      </h2>
      <ul className="ach-grid">
        {ACHIEVEMENTS.map((a) => {
          const got = earned.has(a.id);
          return (
            <li key={a.id} className={got ? "ach on" : "ach"} title={a.how}>
              <span className="ach-icon" aria-hidden>
                {a.icon}
              </span>
              <b>{a.name}</b>
              <small>{got ? "Unlocked" : a.how}</small>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
