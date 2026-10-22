import Link from "next/link";
import type { BoardRow } from "@/lib/chalk";
import { Avatar } from "./Avatar";

/** The Chalkboard: members ranked by season Chalk. */
export function Leaderboard({ rows, target, emptyNote }: { rows: BoardRow[]; target: number; emptyNote?: React.ReactNode }) {
  return (
    <div className="board">
      <div className="board-head">
        <span>#</span>
        <span className="h-id">Lift</span>
        <span>Member</span>
        <span className="r">Chalk</span>
        <span className="r h-wl">Meets</span>
      </div>
      {rows.length === 0 ? (
        <div className="empty">
          <b>The board is waiting</b>
          {emptyNote ?? "Check in at the next meet to put the first Chalk on the board."}
        </div>
      ) : (
        rows.map((r, i) => (
          <Link key={r.handle} href={`/members/${r.handle}`} className="board-row">
            <span className="rank">{i === 0 ? "♛" : i + 1}</span>
            <span className="rid">{r.chalk >= target ? "✓" : `${Math.round((r.chalk / target) * 100)}%`}</span>
            <span className="who">
              <Avatar src={null} name={r.display_name} />
              <span style={{ minWidth: 0 }}>
                <b>{r.display_name}</b>
                <small>{i === 0 ? "Top Riser so far" : `@${r.handle}`}</small>
              </span>
            </span>
            <span className="elo">{r.chalk}</span>
            <span className="wl">{r.meets}</span>
          </Link>
        ))
      )}
    </div>
  );
}
