// Incremental build pipeline: modern ABAP (src/) -> downport 7.02 (.downport/) -> JS (output/).
//
// Change detection: .buildcache.json stores a content hash per source file plus
// a fingerprint of the configs and the deps/ library. On each build:
//   - nothing changed            -> skip everything (sub-second no-op)
//   - some src files changed     -> only those are re-copied into .downport/ and
//                                   re-downported; transpile runs on the whole set
//                                   (the transpiler needs the full registry anyway)
//   - config/deps changed        -> full rebuild from scratch
// Use `node tools/build.mjs --force` to ignore the cache.
//
// Note: the transpile step itself is monolithic by design (whole-program type
// resolution), but its cost is dominated by open-abap-core and stays ~constant
// no matter how big src/ grows.

import { execSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
  cpSync, rmSync, mkdirSync, writeFileSync, readFileSync, existsSync, readdirSync, statSync, unlinkSync,
} from "node:fs";
import { join, dirname, relative } from "node:path";

const WORK = ".downport";
const CACHE_FILE = ".buildcache.json";
const FORCE = process.argv.includes("--force");

function listFiles(dir) {
  const out = [];
  if (!existsSync(dir)) return out;
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) out.push(...listFiles(full));
    else out.push(full);
  }
  return out;
}

const sha1 = (buf) => createHash("sha1").update(buf).digest("hex");
const hashFile = (f) => sha1(readFileSync(f));

// overlay patches: files under tools/patches/<lib>/... replace the same path in
// deps/<lib>/... (used to fix todo-stubs in open-abap-core, e.g. ixml set_validating).
// Applied before fingerprinting so the cache stays consistent; survives re-cloning deps.
function applyDepsPatches() {
  const patchRoot = join("tools", "patches");
  for (const patch of listFiles(patchRoot)) {
    const target = join("deps", relative(patchRoot, patch));
    const lib = relative(patchRoot, patch).split(/[\\/]/)[0];
    if (!existsSync(join("deps", lib))) continue; // lib not cloned locally
    if (existsSync(target) && readFileSync(patch).equals(readFileSync(target))) continue;
    mkdirSync(dirname(target), { recursive: true });
    cpSync(patch, target);
    console.log(`[build] patched ${target}`);
  }
}
applyDepsPatches();
// Anchored fixups: tiny targeted edits to deps sources. Unlike the file
// overlay above these FAIL LOUDLY when upstream changes the code around the
// anchor - an upstream update can never be silently reverted.
//
// Currently EMPTY - upstream now guards every SAP-GUI-only spot itself:
//   - a4006a8 "Use ZIF_EUI_OLE": the PERFORM IN PROGRAM ('Z_XTT_DEBUG') debug
//     hook is commented out at the source, and the raw
//     `CALL METHOD OF cv_ole_doc 'SaveAs'` tail became `eo_ole->save_as( )` -
//     an ordinary method call, skipped here because compat/eui's open_by_ole
//     returns an unbound reference.
//   - 097cc7b "adapt for Open ABAP": the BAL pushbutton block now sits behind
//     `AND zcl_eui_menu=>can_show( ) = abap_true`, and compat/eui's can_show
//     returns abap_false.
// The machinery stays for the next SAP-only statement upstream introduces.
const FIXUPS = [];
for (const f of FIXUPS) {
  const src = readFileSync(f.file, "utf8").replace(/\r\n/g, "\n");
  if (src.includes(f.replace)) continue; // already applied
  if (!src.includes(f.find)) {
    throw new Error(`[build] FIXUP ANCHOR NOT FOUND in ${f.file} (${f.reason}) - upstream changed, review the fixup`);
  }
  writeFileSync(f.file, src.replace(f.find, f.replace));
  console.log(`[build] fixup applied: ${f.file} (${f.reason})`);
}


// fingerprint of things that force a full rebuild: configs + deps library state
// (deps files are fingerprinted by path/size/mtime - hashing 600+ files would be slower)
function depsFingerprint() {
  const parts = [];
  for (const f of [...listFiles("deps"), ...listFiles("compat")]) {
    const st = statSync(f);
    parts.push(`${f}:${st.size}:${st.mtimeMs}`);
  }
  return sha1(parts.join("|"));
}

function globalFingerprint() {
  // the pipeline itself is part of the fingerprint: changing build/transpile
  // logic must invalidate the cache
  const configs = ["abap_transpile.json", "package.json", "tools/build.mjs", "tools/transpile.mjs"]
    .map((f) => (existsSync(f) ? hashFile(f) : "missing"))
    .join("|");
  return sha1(configs + "|" + depsFingerprint());
}

// ---- collect current state ------------------------------------------------
const srcFiles = listFiles("src");
const current = { global: globalFingerprint(), files: {} };
for (const f of srcFiles) {
  current.files[f.replace(/\\/g, "/")] = hashFile(f);
}

let previous = { global: "", files: {} };
if (!FORCE && existsSync(CACHE_FILE)) {
  try {
    previous = JSON.parse(readFileSync(CACHE_FILE, "utf8"));
  } catch {
    // corrupt cache -> full rebuild
  }
}

const fullRebuild = FORCE || previous.global !== current.global || !existsSync(WORK);
const changed = [];
const removed = [];
if (!fullRebuild) {
  for (const [f, h] of Object.entries(current.files)) {
    if (previous.files[f] !== h) changed.push(f);
  }
  for (const f of Object.keys(previous.files)) {
    if (current.files[f] === undefined) removed.push(f);
  }
  if (changed.length === 0 && removed.length === 0 && existsSync("output")) {
    console.log("[build] up to date - nothing changed (use --force to rebuild)");
    process.exit(0);
  }
}

// ---- stage 0: sync src -> .downport ----------------------------------------
if (fullRebuild) {
  console.log("[build] full rebuild (config/deps changed, --force, or first run)");
  rmSync(WORK, { recursive: true, force: true });
  mkdirSync(WORK, { recursive: true });
  cpSync("src", `${WORK}/src`, { recursive: true });
} else {
  console.log(`[build] incremental: ${changed.length} changed, ${removed.length} removed`);
  for (const f of changed) {
    const target = join(WORK, f);
    mkdirSync(dirname(target), { recursive: true });
    cpSync(f, target);
  }
  for (const f of removed) {
    const target = join(WORK, f);
    if (existsSync(target)) unlinkSync(target);
    // drop stale transpiled output of removed sources
    const base = f.replace(/^src\//, "").replace(/^.*\//, "").replace(/\.abap$|\.xml$/, "");
    for (const out of listFiles("output")) {
      if (relative("output", out).startsWith(base)) unlinkSync(out);
    }
  }
}

// abaplint config for the downport step: target 7.02 + downport rule with fixes
const downportConfig = {
  global: { files: "/src/**/*.*" },
  dependencies: [
    {
      url: "https://github.com/open-abap/open-abap-core",
      folder: "/../deps/open-abap-core",
      files: "/src/**/*.*",
    },
    {
      url: "https://github.com/open-abap/open-abap-bal",
      folder: "/../deps/open-abap-bal",
      files: "/src/**/*.*",
    },
    {
      folder: "/../compat/eui",
      files: "/src/*.*",
    },
    {
      url: "https://github.com/bizhuka/xtt",
      folder: "/../deps/xtt",
      files: "/src/*.*",
    },
  ],
  syntax: {
    version: "v702",
    errorNamespace: "^(Z|Y|LCL\\_|TY\\_|LIF\\_)",
  },
  rules: {
    downport: true,
  },
};
writeFileSync(`${WORK}/abaplint.json`, JSON.stringify(downportConfig, null, 2));

// ---- stage 1: downport ------------------------------------------------------
console.log("[build] step 1/2: downport modern ABAP -> 7.02 (abaplint --fix)");
execSync("npx abaplint abaplint.json --fix", { cwd: WORK, stdio: "inherit" });

// ---- stage 1b: downport libs written in modern ABAP (e.g. bizhuka/xtt) --------
// Their sources go through the same abaplint --fix cycle into .downport/libs/<n>;
// tools/transpile.mjs then consumes the downported copy instead of deps/<n>.
// Cached: re-runs only when the lib fingerprint changes.
const DOWNPORT_LIBS = [
  {
    name: "xtt",
    src: join("deps", "xtt", "src"),
    exclude: /file_grid|file_oaor|file_smw0|zcl_xtt_pdf|013_err_repair|testclasses/i,
  },
];

function libFingerprint(dir) {
  const parts = [];
  for (const f of listFiles(dir)) {
    const st = statSync(f);
    parts.push(`${f}:${st.size}:${st.mtimeMs}`);
  }
  return sha1(parts.join("|"));
}

// The transpiler scopes DATA declared inside IF/TRY/LOOP blocks to the JS
// block (ABAP semantics is method scope) -> ReferenceError when used after
// the block. Hoisting single-line declarations to the top of the method is
// semantically neutral in ABAP and sidesteps the bug for ported libs.
// NO_HOIST=1 disables the workaround, to re-check whether the transpiler bug is
// fixed upstream (as of @abaplint/transpiler 2.13.52 it is not: the suite dies
// with "ReferenceError: l_x_value is not defined" in zcl_xtt_excel_xlsx).
const HOIST = process.env.NO_HOIST !== "1";
const HOIST_VERSION = HOIST ? "hoist-v4" : "hoist-off"; // TYPE only (LIKE is order-dependent); v3: single-line DATA: chains; v4: only from nested blocks (method-top DATA may follow local TYPES)
function hoistDataDeclarations(dir) {
  const OPEN  = /^(IF|LOOP|DO|WHILE|TRY|CASE)\b|^DO\.$/;
  const CLOSE = /^(ENDIF|ENDLOOP|ENDDO|ENDWHILE|ENDTRY|ENDCASE)\b/;
  for (const f of listFiles(dir)) {
    if (!f.endsWith(".abap")) continue;
    const lines = readFileSync(f, "utf8").split(/\r?\n/);
    const out = [];
    let methodStart = -1;
    let hoisted = 0;
    let depth = 0;
    for (const line of lines) {
      const t = line.trim().toUpperCase();
      if (t.startsWith("METHOD ") || t === "METHOD.") {
        out.push(line);
        methodStart = out.length;
        hoisted = 0;
        depth = 0;
        continue;
      }
      if (t.startsWith("ENDMETHOD")) {
        methodStart = -1;
        out.push(line);
        continue;
      }
      const isPlainData = /^\s*DATA\s+\w+\s+TYPE\s+.*\.\s*(".*)?$/i.test(line);
      const isChainData = /^\s*DATA:\s*\w+\s+TYPE\s+[^,.]+(\s*,\s*\w+\s+TYPE\s+[^,.]+)*\s*\.\s*(".*)?$/i.test(line);
      // only hoist out of nested blocks; top-level DATA stays in place so it
      // can follow method-local TYPES declarations (e.g. zcl_xtt_image)
      if (methodStart >= 0 && depth > 0 && (isPlainData || isChainData)) {
        out.splice(methodStart + hoisted, 0, line);
        hoisted++;
        continue;
      }
      if (methodStart >= 0) {
        if (OPEN.test(t)) depth++;
        else if (CLOSE.test(t)) depth = Math.max(0, depth - 1);
      }
      out.push(line);
    }
    writeFileSync(f, out.join("\n"));
  }
}

const libState = existsSync(".buildcache-libs.json")
  ? JSON.parse(readFileSync(".buildcache-libs.json", "utf8"))
  : {};

for (const lib of DOWNPORT_LIBS) {
  const outDir = join(WORK, "libs", lib.name);
  const print = libFingerprint(lib.src) + "|" + sha1(JSON.stringify(downportConfig)) + "|" + HOIST_VERSION;
  if (libState[lib.name] === print && existsSync(join(outDir, "src"))) {
    continue; // up to date
  }
  console.log(`[build] step 1b: downport lib ${lib.name}`);
  rmSync(outDir, { recursive: true, force: true });
  mkdirSync(join(outDir, "src"), { recursive: true });
  for (const f of listFiles(lib.src)) {
    if (dirname(f) !== lib.src) continue;          // top level only (skips demo/)
    if (lib.exclude.test(f)) continue;
    cpSync(f, join(outDir, "src", relative(lib.src, f)));
  }
  // same downport config, but dependency paths are one level deeper
  const libConfig = JSON.parse(JSON.stringify(downportConfig));
  for (const dep of libConfig.dependencies) {
    if (dep.folder !== undefined) dep.folder = "/../../.." + dep.folder.slice(3);
  }
  // the lib must not depend on its own deps/ copy
  libConfig.dependencies = libConfig.dependencies.filter(
    (d) => !(d.folder ?? "").endsWith(`/deps/${lib.name}`));
  writeFileSync(join(outDir, "abaplint.json"), JSON.stringify(libConfig, null, 2));
  execSync("npx abaplint abaplint.json --fix", { cwd: outDir, stdio: "inherit" });
  if (HOIST) hoistDataDeclarations(join(outDir, "src"));
  libState[lib.name] = print;
}
writeFileSync(".buildcache-libs.json", JSON.stringify(libState, null, 1));

// ---- stage 2: transpile ------------------------------------------------------
console.log("[build] step 2/2: transpile 7.02 -> JavaScript (+ source maps)");
execSync("node tools/transpile.mjs", { stdio: "inherit" });

writeFileSync(CACHE_FILE, JSON.stringify(current, null, 1));
console.log("[build] done: output/ is up to date");
