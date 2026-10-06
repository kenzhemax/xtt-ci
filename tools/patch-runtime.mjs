// Local workaround for @abaplint/runtime, applied to node_modules on disk so
// it survives `npm install` (build.mjs calls this first). Same mechanism as
// localABAP's tools/patch-runtime.mjs.
//
// Each entry is removed as soon as the fix ships upstream: `applied` is the
// code we want, `broken` the code we replace. If neither matches, the upstream
// implementation changed and the entry needs review - the build stops and
// says so instead of silently running without the fix.

import { readFileSync, writeFileSync, existsSync } from "node:fs";

const PATCHES = [
  {
    // `lo_var ?= mo_value` with a LOCAL target class was never checked: cast()
    // looks the class up by its bare name (LCL_NODE_VAR), but local classes are
    // registered as CLAS-<pool>-<name> / PROG-<prog>-<name>, so the lookup
    // misses, no CX_SY_MOVE_CAST_ERROR is raised and the wrong object gets
    // through. xtt's ;cond= evaluator relies on that exception
    // (lcl_node_user_format, test DEMO_USER_FORMATS; demo 130 in make_all).
    name: "down cast to a local class",
    file: "node_modules/@abaplint/runtime/build/src/statements/cast.js",
    broken: String.raw`        targetClass = abap.Classes["PROG-ZFOOBAR-" + targetName];
    }
    if (targetClass?.INTERNAL_TYPE === "CLAS") {`,
    applied: String.raw`        targetClass = abap.Classes["PROG-ZFOOBAR-" + targetName];
    }
    // xtt-ci runtime patch: find a local class via the reference's RTTI name
    if (targetClass === undefined && typeof target.getRTTIName === "function") {
        const m = /^\\(CLASS-POOL|PROGRAM)=([^\\]+)\\CLASS=([^\\]+)$/i.exec(target.getRTTIName() ?? "");
        const local = m ? abap.Classes[(m[1].toUpperCase() === "PROGRAM" ? "PROG-" : "CLAS-") +
            m[2].toUpperCase() + "-" + m[3].toUpperCase()] : undefined;
        if (local?.INTERNAL_TYPE === "CLAS") {
            targetClass = local;
        }
    }
    if (targetClass?.INTERNAL_TYPE === "CLAS") {`,
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
