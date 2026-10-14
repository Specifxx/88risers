import Link from "next/link";
import type { Puller } from "@/lib/data";
import { formatId } from "@/lib/site";
import { tierFor } from "@/lib/elo";
import { Avatar } from "./Avatar";

export function Leaderboard({ rows, emptyNote }: { rows: Puller[]; emptyNote?: React.ReactNode }) {
  return (
    <div className="board">
      <div className="board-head">
        <span>#</span>
        <span className="h-id">ID</span>
        <span>Puller</span>
        <span className="r">Elo</span>
        <span className="r h-wl">W–L</span>
      </div>
      {rows.length === 0 ? (
        <div className="empty">
          <b>The board is waiting</b>
          {emptyNote ?? "Rankings go live after the first 88 Risers tournament. Every match counts from day one."}
        </div>
      ) : (
        rows.map((p, i) => (
          <Link key={p.id} href={`/pullers/${p.id}`} className="board-row">
            <span className="rank">{i + 1}</span>
            <span className="rid">{formatId(p.id)}</span>
            <span className="who">
              <Avatar src={p.photo_url || p.card_url} name={p.name} />
              <span style={{ minWidth: 0 }}>
                <b>{p.name}</b>
                <small>{tierFor(p.elo).name}</small>
              </span>
            </span>
            <span className="elo">{p.elo}</span>
            <span className="wl">
              {p.wins}–{p.losses}
            </span>
          </Link>
        ))
      )}
    </div>
  );
}
