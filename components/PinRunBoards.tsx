"use client";

import Link from "next/link";
import { useState } from "react";

type Row = { display_name: string; handle: string; best: number };

/** Pin Run high scores, one tab per level. */
export function PinRunBoards({ boards }: { boards: { label: string; rows: Row[]; empty: string; note?: string; unit?: string }[] }) {
  const [on, setOn] = useState(0);
  const b = boards[on];
  return (
    <>
      <h2 className="panel-title">High scores</h2>
      <div className="board-tabs" role="tablist">
        {boards.map((x, i) => (
          <button key={x.label} type="button" role="tab" aria-selected={i === on} onClick={() => setOn(i)}>
            {x.label}
          </button>
        ))}
      </div>
      {b.note ? <p className="board-note">{b.note}</p> : null}
      <ol className="coin-leaders">
        {b.rows.map((t, i) => (
          <li key={t.handle}>
            <span className="cl-rank">{i === 0 ? "♛" : i + 1}</span>
            <Link className="cl-name" href={`/members/${t.handle}`}>
              {t.display_name}
            </Link>
            <b>
              {t.best.toLocaleString("en-AU")}
              {b.unit ? <small> {b.unit}</small> : null}
            </b>
          </li>
        ))}
        {b.rows.length === 0 ? <li className="muted">{b.empty}</li> : null}
      </ol>
    </>
  );
}
