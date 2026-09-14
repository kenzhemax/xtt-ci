// Database setup hook, wired into the generated output/_init.mjs via
// abap_transpile.json -> options.setup { filename, preFunction: "connect" }.
//
// The SQLite driver (@abaplint/database-sqlite) is sql.js: an in-memory database
// loaded from / exported to a byte image (data/local.sqlite).
//
// Schema migration (SE14-style, see PLAN.md Phase 9): on connect the DDIC-generated
// CREATE TABLEs are compared with the actual schema.
//   - table missing                -> CREATE TABLE
//   - only new columns added       -> ALTER TABLE ADD COLUMN (initial '' / 0)
//   - anything else (drop/retype/  -> QCM-style conversion: create tmp table with
//     resize/key change)              the new layout, copy shared columns (CHAR
//                                     values truncated to the new length), drop
//                                     old, rename tmp
// Before ANY change the current db file is backed up to data/backup/.
// MIGRATE_DRY_RUN=1 prints the plan without applying (npm run migrate -- --dry-run).

import { SQLiteDatabaseClient } from "@abaplint/database-sqlite";
import { readFileSync, writeFileSync, existsSync, mkdirSync, copyFileSync } from "node:fs";
import { dirname, resolve, join } from "node:path";
import { fileURLToPath } from "node:url";

const DB_FILE = resolve(dirname(fileURLToPath(import.meta.url)), "..", "data", "local.sqlite");

// ---------- DDL parsing (format produced by the transpiler) -------------------
// CREATE TABLE 'ztrip' ('trip_id' NCHAR(10) COLLATE RTRIM, ..., PRIMARY KEY('trip_id'));
function parseCreate(stmt) {
  const m = stmt.trim().match(/^CREATE TABLE '([^']+)' \((.*)\);?$/s);
  if (!m) return null;
  const name = m[1];
  let body = m[2];
  let pk = [];
  const pkm = body.match(/,\s*PRIMARY KEY\(([^)]*)\)\s*$/);
  if (pkm) {
    pk = pkm[1].split(",").map((s) => s.replace(/'/g, "").trim());
    body = body.slice(0, pkm.index);
  }
  const cols = body.split(/,(?=\s*')/).map((c) => {
    const cm = c.trim().match(/^'([^']+)'\s+(.*)$/);
    return { name: cm[1], def: cm[2].trim(), type: cm[2].trim().split(" ")[0] };
  });
  return { name, pk, cols, stmt };
}

const isNumeric = (type) => /^(INT|DECIMAL|REAL|NUMERIC|DOUBLE|FLOAT|BIGINT|SMALLINT)/i.test(type);
const charLength = (type) => {
  const m = type.match(/^N?(?:VAR)?CHAR\((\d+)\)$/i);
  return m ? Number(m[1]) : null;
};

// ---------- actual schema ------------------------------------------------------
async function actualTable(client, name) {
  const exists = await client.select({
    select: `SELECT name FROM sqlite_master WHERE type='table' AND name='${name}'`,
  });
  if (exists.rows.length === 0) return null;
  const info = await client.select({
    select: `SELECT name, type, pk FROM pragma_table_info('${name}') ORDER BY cid`,
  });
  return {
    cols: info.rows.map((r) => ({ name: String(r.name), type: String(r.type) })),
    pk: info.rows.filter((r) => Number(r.pk) > 0)
      .sort((a, b) => Number(a.pk) - Number(b.pk)).map((r) => String(r.name)),
  };
}

// ---------- plan ---------------------------------------------------------------
async function planMigration(client, ddlList) {
  const plan = [];
  for (const stmt of ddlList) {
    const target = parseCreate(stmt);
    if (target === null) continue;
    const actual = await actualTable(client, target.name);

    if (actual === null) {
      plan.push({ kind: "create", table: target.name, target });
      continue;
    }

    const sameCol = (a, t) => a.name === t.name && a.type.toUpperCase() === t.type.toUpperCase();
    const actualByName = new Map(actual.cols.map((c) => [c.name, c]));
    const targetByName = new Map(target.cols.map((c) => [c.name, c]));
    const added = target.cols.filter((c) => !actualByName.has(c.name));
    const removed = actual.cols.filter((c) => !targetByName.has(c.name));
    const changed = target.cols.filter((c) =>
      actualByName.has(c.name) && !sameCol(actualByName.get(c.name), c));
    const pkChanged = JSON.stringify(actual.pk) !== JSON.stringify(target.pk);

    if (added.length === 0 && removed.length === 0 && changed.length === 0 && !pkChanged) {
      continue; // identical
    }
    if (removed.length === 0 && changed.length === 0 && !pkChanged) {
      plan.push({ kind: "add", table: target.name, added });
    } else {
      plan.push({
        kind: "convert", table: target.name, target,
        shared: target.cols.filter((c) => actualByName.has(c.name)),
        details: [
          ...added.map((c) => `+${c.name} ${c.type}`),
          ...removed.map((c) => `-${c.name}`),
          ...changed.map((c) => `~${c.name} ${actualByName.get(c.name).type} -> ${c.type}`),
          ...(pkChanged ? [`key: (${actual.pk}) -> (${target.pk})`] : []),
        ],
      });
    }
  }
  return plan;
}

// ---------- apply ----------------------------------------------------------------
async function applyMigration(client, plan) {
  for (const step of plan) {
    if (step.kind === "create") {
      console.log(`[migrate] CREATE TABLE ${step.table}`);
      await client.execute(step.target.stmt);
    } else if (step.kind === "add") {
      for (const col of step.added) {
        const dflt = isNumeric(col.type) ? "0" : "''";
        console.log(`[migrate] ALTER TABLE ${step.table} ADD COLUMN ${col.name} ${col.def}`);
        await client.execute(
          `ALTER TABLE '${step.table}' ADD COLUMN '${col.name}' ${col.def} DEFAULT ${dflt}`);
      }
    } else if (step.kind === "convert") {
      const tmp = `_qcm_${step.table}`;
      console.log(`[migrate] CONVERT ${step.table} (${step.details.join(", ")})`);
      const tmpDdl = step.target.stmt.replace(`'${step.table}'`, `'${tmp}'`);
      const colList = step.shared.map((c) => `"${c.name}"`).join(", ");
      const selList = step.shared.map((c) => {
        const len = charLength(c.type);
        return len === null ? `"${c.name}"` : `substr("${c.name}", 1, ${len})`;
      }).join(", ");
      await client.execute(`DROP TABLE IF EXISTS '${tmp}'`);
      await client.execute(tmpDdl);
      await client.execute(
        `INSERT INTO '${tmp}' (${colList}) SELECT ${selList} FROM '${step.table}'`);
      await client.execute(`DROP TABLE '${step.table}'`);
      await client.execute(`ALTER TABLE '${tmp}' RENAME TO '${step.table}'`);
    }
  }
}

function backupNow() {
  const dir = join(dirname(DB_FILE), "backup");
  mkdirSync(dir, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const target = join(dir, `local-${stamp}.sqlite`);
  copyFileSync(DB_FILE, target);
  console.log(`[migrate] backup: data/backup/${stamp}.sqlite`.replace(stamp, `local-${stamp}`));
  return target;
}

// ---------- entry points ----------------------------------------------------------
export async function connect(abap, schemas, insert) {
  const client = new SQLiteDatabaseClient();
  const fresh = existsSync(DB_FILE) === false;

  await client.connect(fresh ? undefined : readFileSync(DB_FILE));

  if (fresh) {
    await client.execute(schemas.sqlite);
    for (const stmt of insert) {
      try {
        await client.execute(stmt);
      } catch {
        // ignore duplicate seed data
      }
    }
  } else {
    const plan = await planMigration(client, schemas.sqlite);
    if (process.env.MIGRATE_DRY_RUN === "1") {
      if (plan.length === 0) {
        console.log("[migrate] dry-run: schema is up to date, nothing to do");
      } else {
        console.log("[migrate] dry-run: planned actions (NOT applied):");
        for (const s of plan) {
          if (s.kind === "create") console.log(`  CREATE TABLE ${s.table}`);
          if (s.kind === "add") console.log(`  ALTER TABLE ${s.table} ADD ${s.added.map((c) => c.name + " " + c.type).join(", ")}`);
          if (s.kind === "convert") console.log(`  CONVERT ${s.table} (${s.details.join(", ")})`);
        }
      }
    } else if (plan.length > 0) {
      backupNow();
      await applyMigration(client, plan);
    }
  }

  abap.context.databaseConnections["DEFAULT"] = client;
}

export function saveDatabase() {
  const client = globalThis.abap?.context?.databaseConnections?.["DEFAULT"];
  if (client === undefined || typeof client.export !== "function") {
    return false;
  }
  mkdirSync(dirname(DB_FILE), { recursive: true });
  writeFileSync(DB_FILE, Buffer.from(client.export()));
  return true;
}
