import "server-only";
import { liveDatabaseUrl, oldDatabaseUrl } from "./db";

/**
 * One-time copy of every table from the previous database into the live one, used when the site
 * moves to a new Neon database. Reads only from the old database (it's never changed).
 *
 * Rows are upserted by primary key, so the old data replaces the starter rows a fresh database
 * seeds itself with (founders, TV, settings) while anything created since the switch is kept.
 * Tables go in foreign-key order; a column that points at its own table (accounts.invited_by) is
 * filled in afterwards. Sequences are moved past the highest id so new rows don't collide.
 */
type Sql = import("postgres").Sql;

const q = (id: string) => `"${id.replace(/"/g, '""')}"`;

async function connect(url: string): Promise<Sql> {
  const { default: postgres } = await import("postgres");
  return postgres(url, { max: 1, prepare: false, connect_timeout: 15, idle_timeout: 5, onnotice: () => {} });
}

async function tablesInOrder(sql: Sql): Promise<string[]> {
  const tables = (
    await sql<{ t: string }[]>`SELECT table_name AS t FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE'`
  ).map((r) => r.t);
  const deps = await sql<{ child: string; parent: string }[]>`
    SELECT c.conrelid::regclass::text AS child, c.confrelid::regclass::text AS parent
    FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace
    WHERE c.contype = 'f' AND n.nspname = 'public'`;
  const need = new Map(tables.map((t) => [t, new Set<string>()]));
  for (const d of deps) {
    const child = d.child.replace(/"/g, "");
    const parent = d.parent.replace(/"/g, "");
    if (child !== parent && need.has(child) && need.has(parent)) need.get(child)!.add(parent);
  }
  const out: string[] = [];
  const done = new Set<string>();
  while (out.length < tables.length) {
    const ready = tables.filter((t) => !done.has(t) && [...need.get(t)!].every((p) => done.has(p)));
    if (!ready.length) {
      out.push(...tables.filter((t) => !done.has(t))); // a cycle: fall back to name order
      break;
    }
    for (const t of ready.sort()) {
      out.push(t);
      done.add(t);
    }
  }
  return out;
}

export type ImportResult = { tables: { name: string; rows: number }[]; skipped: string[] };

export async function importFromOldDatabase(): Promise<ImportResult> {
  const oldUrl = oldDatabaseUrl();
  const newUrl = liveDatabaseUrl();
  if (!oldUrl) throw new Error("No old database is set (OLD_DATABASE_URL, or DATABASE_URL alongside RISERS_DB_URL).");
  if (!newUrl) throw new Error("No live database is set.");
  if (oldUrl === newUrl) throw new Error("The old and live database are the same.");
  const src = await connect(oldUrl);
  const dst = await connect(newUrl);
  const result: ImportResult = { tables: [], skipped: [] };
  try {
    const order = await tablesInOrder(src);
    const liveTables = new Set(
      (await dst<{ t: string }[]>`SELECT table_name AS t FROM information_schema.tables WHERE table_schema = 'public'`).map((r) => r.t),
    );
    for (const table of order) {
      if (!liveTables.has(table)) {
        result.skipped.push(table);
        continue;
      }
      const srcCols = (await src<{ c: string }[]>`SELECT column_name AS c FROM information_schema.columns WHERE table_schema = 'public' AND table_name = ${table} ORDER BY ordinal_position`).map((r) => r.c);
      const dstCols = new Set((await dst<{ c: string }[]>`SELECT column_name AS c FROM information_schema.columns WHERE table_schema = 'public' AND table_name = ${table}`).map((r) => r.c));
      const cols = srcCols.filter((c) => dstCols.has(c));
      const pk = (
        await dst<{ c: string }[]>`
          SELECT a.attname AS c FROM pg_index i
          JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
          WHERE i.indrelid = ${`public.${q(table)}`}::regclass AND i.indisprimary`
      ).map((r) => r.c);
      const selfRef = (
        await dst<{ c: string }[]>`
          SELECT a.attname AS c FROM pg_constraint k
          JOIN pg_attribute a ON a.attrelid = k.conrelid AND a.attnum = ANY(k.conkey)
          WHERE k.contype = 'f' AND k.conrelid = ${`public.${q(table)}`}::regclass AND k.confrelid = k.conrelid`
      ).map((r) => r.c);

      const colList = cols.map(q).join(", ");
      const nonPk = cols.filter((c) => !pk.includes(c));
      const conflict = pk.length
        ? nonPk.length
          ? `ON CONFLICT (${pk.map(q).join(", ")}) DO UPDATE SET ${nonPk.map((c) => `${q(c)} = EXCLUDED.${q(c)}`).join(", ")}`
          : `ON CONFLICT (${pk.map(q).join(", ")}) DO NOTHING`
        : "ON CONFLICT DO NOTHING";
      const batchSize = cols.includes("data") ? 10 : 200; // photos carry image bytes
      let rows = 0;
      const deferred: Record<string, unknown>[] = [];

      const cursor = src.unsafe(`SELECT ${colList} FROM public.${q(table)}`).cursor(batchSize);
      for await (const batch of cursor) {
        for (const row of batch as Record<string, unknown>[]) {
          if (selfRef.length && pk.length) {
            deferred.push(Object.fromEntries([...pk, ...selfRef].map((c) => [c, row[c]])));
            for (const c of selfRef) row[c] = null;
          }
        }
        const params: unknown[] = [];
        const values = (batch as Record<string, unknown>[])
          .map((row) => `(${cols.map((c) => (params.push(row[c]), `$${params.length}`)).join(", ")})`)
          .join(", ");
        await dst.unsafe(`INSERT INTO public.${q(table)} (${colList}) VALUES ${values} ${conflict}`, params as never[]);
        rows += batch.length;
      }
      for (const d of deferred) {
        const params = [...selfRef.map((c) => d[c]), ...pk.map((c) => d[c])];
        const set = selfRef.map((c, i) => `${q(c)} = $${i + 1}`).join(", ");
        const where = pk.map((c, i) => `${q(c)} = $${selfRef.length + i + 1}`).join(" AND ");
        await dst.unsafe(`UPDATE public.${q(table)} SET ${set} WHERE ${where}`, params as never[]);
      }
      // keep serial ids ahead of the imported rows
      for (const c of cols) {
        const [{ seq }] = await dst<{ seq: string | null }[]>`SELECT pg_get_serial_sequence(${`public.${q(table)}`}, ${c}) AS seq`;
        if (seq) await dst.unsafe(`SELECT setval('${seq.replace(/'/g, "''")}', greatest((SELECT coalesce(max(${q(c)}), 0) FROM public.${q(table)}), 1))`);
      }
      result.tables.push({ name: table, rows });
    }
  } finally {
    await src.end({ timeout: 5 }).catch(() => {});
    await dst.end({ timeout: 5 }).catch(() => {});
  }
  return result;
}
