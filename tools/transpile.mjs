// Transpile step: .downport/src + deps libs -> output/ (JS + SOURCE MAPS).
//
// This replaces `abap_transpile` (transpiler-cli): the CLI has a bug that makes
// it never write source maps (impossible `&&` condition on the object type),
// and we also want map sources to point back at real .abap files so VS Code
// can set breakpoints in ABAP. Logic is a faithful port of
// transpiler/packages/cli/src/index.ts with those two fixes.
//
// Map targets: if a file survived downporting unchanged, the map points at the
// original src/ file; otherwise at the .downport/ copy (readable 7.02 ABAP).

import * as fs from "node:fs";
import * as path from "node:path";
import { execSync } from "node:child_process";
import * as os from "node:os";
import * as abaplint from "@abaplint/core";
// PERFORM...CHANGING fix is upstream since @abaplint/transpiler 2.13.42
// (abaplint/transpiler#1763) - the local pre-import patch is gone.
import { Transpiler } from "@abaplint/transpiler";

const config = JSON.parse(fs.readFileSync("abap_transpile.json", "utf8"));

function listFiles(dir) {
  const out = [];
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...listFiles(full));
    else out.push(full);
  }
  return out;
}

// ---- input files ------------------------------------------------------------
// filename = basename (that is what ends up in the source map "sources"),
// mapTarget = where the map should point, relative to output/
const inputs = [];
for (const full of listFiles(config.input_folder)) {
  const base = path.basename(full);
  const rel = path.relative(config.input_folder, full).replace(/\\/g, "/");
  const original = path.join("src", rel);
  let mapTarget = "../" + config.input_folder.replace(/\\/g, "/") + "/" + rel;
  if (fs.existsSync(original)
      && fs.readFileSync(original).equals(fs.readFileSync(full))) {
    mapTarget = "../src/" + rel; // untouched by downport -> map to the real source
  }
  inputs.push({ filename: base, contents: fs.readFileSync(full, "utf8"), mapTarget });
}

// ---- library files -----------------------------------------------------------
function loadLibs() {
  const files = [];
  for (const lib of config.libs ?? []) {
    let dir = "";
    let cleanup = false;
    if (lib.folder && fs.existsSync(process.cwd() + lib.folder)) {
      console.log("[transpile] lib from folder: " + lib.folder);
      dir = process.cwd() + lib.folder;
    } else {
      console.log("[transpile] lib clone: " + lib.url);
      dir = fs.mkdtempSync(path.join(os.tmpdir(), "abap_transpile-"));
      execSync("git clone --quiet --depth 1 " + lib.url + " .", { cwd: dir, stdio: "inherit" });
      cleanup = true;
    }
    const excludes = (lib.exclude_filter ?? []).map((p) => new RegExp(p, "i"));
    // "/src/*.*" means top-level only (no subfolders like xtt's demo/)
    const recursive = String(lib.files ?? "/src/**/*.*").includes("**");
    let count = 0;
    for (const full of listFiles(path.join(dir, "src"))) {
      const norm = full.replace(/\\/g, "/");
      if (!recursive && path.dirname(full) !== path.join(dir, "src")) continue;
      if (norm.endsWith(".clas.testclasses.abap")) continue;
      if (excludes.some((r) => r.test(norm))) continue;
      files.push({ filename: path.basename(full), contents: fs.readFileSync(full, "utf8") });
      count++;
    }
    console.log(`\t${count} files added from lib`);
    if (cleanup) fs.rmSync(dir, { recursive: true, force: true });
  }
  return files;
}

// ---- transpile ----------------------------------------------------------------
const reg = new abaplint.Registry();
for (const f of inputs) {
  reg.addFile(new abaplint.MemoryFile(f.filename, f.contents));
}
for (const l of loadLibs()) {
  reg.addDependency(new abaplint.MemoryFile(l.filename, l.contents));
}
reg.parse();

console.log("[transpile] building " + reg.getObjectCount().total + " objects");
const t = new Transpiler(config.options);
const output = await t.run(reg);

// ---- write --------------------------------------------------------------------
const outDir = config.output_folder;
fs.mkdirSync(outDir, { recursive: true });

const mapTargets = new Map(inputs.map((f) => [f.filename, f.mapTarget]));
const writeMaps = config.write_source_map === true;
let mapsWritten = 0;

for (const obj of output.objects) {
  let contents = obj.chunk.getCode();
  const isProg = obj.object.type.toUpperCase() === "PROG";

  // maps only for objects built from OUR sources (libs have no map target)
  const hasOwnSource = [...mapTargets.keys()].some((f) =>
    f.startsWith(obj.object.name.toLowerCase() + "."));

  if (writeMaps && hasOwnSource) {
    const mapName = obj.filename + ".map";
    // SourceMappingUrl needs percent-encoding, see microsoft/TypeScript#40951
    contents += `\n//# sourceMappingURL=` + mapName.replace(/#/g, "%23");
    const map = JSON.parse(obj.chunk.getMap(obj.filename));
    map.sources = map.sources.map((s) => mapTargets.get(s) ?? s);
    if (isProg) {
      // the init-import line prepended below shifts every line by one
      map.mappings = ";" + map.mappings;
    }
    fs.writeFileSync(path.join(outDir, mapName), JSON.stringify(map));
    mapsWritten++;
  }

  if (isProg) {
    contents = `if (!globalThis.abap) await import("./_init.mjs");\n` + contents;
  }
  fs.writeFileSync(path.join(outDir, obj.filename), contents);
}

if (config.write_unit_tests === true) {
  fs.writeFileSync(path.join(outDir, "index.mjs"), output.unitTestScript);
  fs.writeFileSync(path.join(outDir, "_unit_open.mjs"), output.unitTestScriptOpen);
}
fs.writeFileSync(path.join(outDir, "init.mjs"), output.initializationScript);
fs.writeFileSync(path.join(outDir, "_init.mjs"), output.initializationScript2);
fs.writeFileSync(path.join(outDir, "_top.mjs"),
  `import runtime from "@abaplint/runtime";\nglobalThis.abap = new runtime.ABAP();`);

console.log(`[transpile] ${output.objects.length} objects written, ${mapsWritten} source maps`);
