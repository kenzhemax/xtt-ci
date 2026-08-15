// Local ABAP runner — executes a transpiled Z-program by name.
//   node tools/run.mjs zr_xtt_suite   run a specific program (= npm run suite)
//   node tools/run.mjs                no argument -> interactive picker
//
// The transpiled module (output/<name>.prog.mjs) self-initializes the ABAP
// runtime on import and runs its top-level code (START-OF-SELECTION etc.).
// WRITE output goes straight to stdout via the runtime's StandardOutConsole.

import { pathToFileURL } from "node:url";
import { existsSync, readdirSync } from "node:fs";
import { resolve } from "node:path";
import { createInterface } from "node:readline/promises";

function catalog() {
  const dir = resolve("src", "zprograms");
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((f) => f.endsWith(".prog.abap"))
    .map((f) => f.replace(/\.prog\.abap$/, ""))
    .sort();
}

let arg = process.argv[2];

if (arg === undefined) {
  // interactive picker, SE38 на минималках
  const programs = catalog();
  if (programs.length === 0) {
    console.error("[run] no programs found in src/zprograms/");
    process.exit(1);
  }
  console.log("\nZ-программы (src/zprograms/):\n");
  programs.forEach((p, i) => console.log(`  ${String(i + 1).padStart(2)}. ${p}`));
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  const answer = (await rl.question("\nНомер программы (Enter = 1): ")).trim();
  rl.close();
  const idx = answer === "" ? 0 : Number(answer) - 1;
  if (Number.isNaN(idx) || idx < 0 || idx >= programs.length) {
    console.error("[run] invalid selection");
    process.exit(1);
  }
  arg = programs[idx];
}

const name = arg.toLowerCase().replace(/\.prog(\.abap)?$/, "");
const file = resolve("output", `${name}.prog.mjs`);

if (!existsSync(file)) {
  console.error(`\n[run] Program not found: ${file}`);
  console.error(`[run] Did you run "npm run build"? Available programs live in src/zprograms/.\n`);
  process.exit(1);
}

console.log(`\n=== Running ${name} (local ABAP, no SAP) ===\n`);
try {
  // initialize via the SEQUENTIAL init script: the static-import variant
  // (_init.mjs) evaluates async sibling modules concurrently, so class
  // registration order is not guaranteed (breaks CLASS_CONSTRUCTORs that
  // look up other classes, e.g. zcl_excel_worksheet -> cl_abap_elemdescr)
  await import(pathToFileURL(resolve("output", "init.mjs")).href);
  await import(pathToFileURL(file).href);
  const { saveDatabase } = await import("./db-setup.mjs");
  if (saveDatabase()) {
    console.log(`\n\n[run] database saved to data/local.sqlite`);
  }

  console.log(`\n=== ${name} finished ===\n`);
} catch (err) {
  console.error(`\n[run] ABAP runtime error in ${name}:`);
  console.error(err);
  process.exit(1);
}
