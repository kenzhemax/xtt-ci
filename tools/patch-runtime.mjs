// Local workaround for @abaplint/runtime, applied to node_modules on disk so
// it survives `npm install` (build.mjs calls this first). Same mechanism as
// localABAP's tools/patch-runtime.mjs.
//
// Each entry is removed as soon as the fix ships upstream: `applied` is the
// code we want, `broken` the code we replace. If neither matches, the upstream
// implementation changed and the entry needs review - the build stops and
// says so instead of silently running without the fix.

import { readFileSync, writeFileSync, existsSync } from "node:fs";

// Earlier entry: the `?=` local class cast, shipped in 2.14.0
// (abaplint/transpiler#1974).
const PATCHES = [
  {
    // runtime 2.14.11 (abaplint/transpiler#2015) maps [:print:] inside a
    // bracket to ASCII only, so xtt's control character filter
    // [^[:print:]\r\n] (zcl_xtt_replace_block) also deletes every non-ASCII
    // letter: Kazakh and Cyrillic text vanished from docx and html. The same
    // file maps [^[:print:]] alone to the control characters, and on a Unicode
    // SAP system [:print:] takes the national letters; this makes print
    // everything but those control characters.
    name: "[:print:] keeps non-ASCII characters",
    file: "node_modules/@abaplint/runtime/build/src/abap_regex.js",
    broken: String.raw`"print": "\\x20-\\x7E",`,
    applied: String.raw`"print": "\\x20-\\x7E\\x80-\\uFFFF",`,
  },
];

export function patchRuntime() {
  for (const p of PATCHES) {
    if (!existsSync(p.file)) {
      throw new Error(`[build] runtime patch "${p.name}": ${p.file} not found - run npm install`);
    }
    const src = readFileSync(p.file, "utf8");
    if (src.includes(p.applied)) continue; // already patched
    if (!src.includes(p.broken)) {
      throw new Error(`[build] runtime patch "${p.name}": upstream code changed - review tools/patch-runtime.mjs ` +
                      `(drop the entry if @abaplint/runtime fixed it)`);
    }
    writeFileSync(p.file, src.replace(p.broken, p.applied));
    console.log(`[build] runtime patched: ${p.name}`);
  }
}
