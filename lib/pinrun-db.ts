import "server-only";
import type { Db } from "./db";
import { getDb } from "./db";
import { DEFAULT_SKIN, RUN_COIN_CAP, type Wallet, plausibleCoins } from "./pinrun";

const EMPTY: Wallet = { coins: 0, skin: DEFAULT_SKIN, owned: [DEFAULT_SKIN] };

export async function getWallet(accountId: number, db?: Db): Promise<Wallet> {
  const d = db ?? (await getDb());
  const [w] = await d.query<Wallet>(`SELECT coins, skin, owned FROM pinrun_wallet WHERE account_id = $1`, [accountId]);
  return w ?? EMPTY;
}

/** Banks the coins from a finished run (no daily limit; a run can't bank more than its score allows); returns how many were saved and the new balance. */
export async function bankRunCoins(accountId: number, score: number, coins: number) {
  const db = await getDb();
  const want = Math.max(0, Math.min(Math.floor(coins) || 0, RUN_COIN_CAP, plausibleCoins(score)));
  return db.transaction(async (tx) => {
    await tx.query(`INSERT INTO pinrun_wallet (account_id) VALUES ($1) ON CONFLICT DO NOTHING`, [accountId]);
    await tx.query(`SELECT 1 FROM pinrun_wallet WHERE account_id = $1 FOR UPDATE`, [accountId]);
    const saved = want;
    if (saved > 0) {
      await tx.query(`UPDATE pinrun_wallet SET coins = coins + $2, updated_at = now() WHERE account_id = $1`, [accountId, saved]);
      await tx.query(`INSERT INTO pinrun_tx (account_id, amount, reason) VALUES ($1, $2, 'Pin Run coins')`, [accountId, saved]);
    }
    const w = await getWallet(accountId, tx);
    return { saved, wallet: w };
  });
}
