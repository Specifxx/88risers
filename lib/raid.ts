import "server-only";
import type { Db } from "./db";
import { getDb } from "./db";
import { type Raid, RAID_HP, RAID_REWARD, RAID_TOP_BONUS } from "./pinrun";

type Row = { id: number; hp_max: number; hp: number };

/**
 * The Riser Boss raid in progress: one health pool the whole club chips at on Level 3 (whichever
 * Riser is chasing you that run). When it falls, a fresh one starts.
 */
async function currentRow(db: Db): Promise<Row> {
  const [r] = await db.query<Row>(`SELECT id, hp_max, hp FROM pinrun_raids WHERE defeated_at IS NULL ORDER BY id DESC LIMIT 1`);
  if (r) return r;
  await db.query(`INSERT INTO pinrun_raids (boss_id, hp_max, hp) VALUES (0, $1, $1)`, [RAID_HP]);
  return currentRow(db);
}

const toRaid = (r: Row): Raid => ({ id: r.id, hp: r.hp, hpMax: r.hp_max });

export async function getRaid(db?: Db): Promise<Raid> {
  return toRaid(await currentRow(db ?? (await getDb())));
}

/** Top damage on the current raid. */
export async function raidBoard(raidId: number, limit = 10) {
  const db = await getDb();
  return db.query<{ display_name: string; handle: string; best: number }>(
    `SELECT a.display_name, a.handle, h.damage AS best FROM pinrun_raid_hits h JOIN accounts a ON a.id = h.account_id
     WHERE h.raid_id = $1 AND h.damage > 0 ORDER BY h.damage DESC, h.updated_at ASC LIMIT $2`,
    [raidId, limit],
  );
}

/**
 * Lands a run's damage on the Riser Boss. If it goes down, everyone who hit it gets Temple coins
 * (the top hitter a bonus), and a fresh Riser Boss starts.
 */
export async function hitRaid(accountId: number, damage: number) {
  const db = await getDb();
  return db.transaction(async (tx) => {
    const cur = await currentRow(tx);
    const [r] = await tx.query<{ hp: number }>(`SELECT hp FROM pinrun_raids WHERE id = $1 FOR UPDATE`, [cur.id]);
    const dealt = Math.max(0, Math.min(Math.floor(damage) || 0, r.hp));
    let killed: null | { reward: number } = null;
    if (dealt > 0) {
      await tx.query(`UPDATE pinrun_raids SET hp = hp - $2 WHERE id = $1`, [cur.id, dealt]);
      await tx.query(
        `INSERT INTO pinrun_raid_hits (raid_id, account_id, damage) VALUES ($1, $2, $3)
         ON CONFLICT (raid_id, account_id) DO UPDATE SET damage = pinrun_raid_hits.damage + EXCLUDED.damage, updated_at = now()`,
        [cur.id, accountId, dealt],
      );
      if (r.hp - dealt <= 0) {
        await tx.query(`UPDATE pinrun_raids SET hp = 0, defeated_at = now() WHERE id = $1`, [cur.id]);
        const hitters = await tx.query<{ account_id: number }>(
          `SELECT account_id FROM pinrun_raid_hits WHERE raid_id = $1 AND damage > 0 ORDER BY damage DESC, updated_at ASC`,
          [cur.id],
        );
        for (const [i, h] of hitters.entries()) {
          const amt = RAID_REWARD + (i === 0 ? RAID_TOP_BONUS : 0);
          await tx.query(`INSERT INTO pinrun_wallet (account_id) VALUES ($1) ON CONFLICT DO NOTHING`, [h.account_id]);
          await tx.query(`UPDATE pinrun_wallet SET coins = coins + $2, updated_at = now() WHERE account_id = $1`, [h.account_id, amt]);
          await tx.query(`INSERT INTO pinrun_tx (account_id, amount, reason) VALUES ($1, $2, $3)`, [
            h.account_id,
            amt,
            `Club Raid: Riser Boss down${i === 0 ? " (top damage)" : ""}`,
          ]);
        }
        killed = { reward: RAID_REWARD };
      }
    }
    return { dealt, raid: toRaid(await currentRow(tx)), killed };
  });
}
