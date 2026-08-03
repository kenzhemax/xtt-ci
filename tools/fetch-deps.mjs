// Clone the ABAP dependencies into deps/ (shallow). Re-run to refresh: an
// existing checkout is left as-is unless FORCE_DEPS=1.
//
// XTT_REPO / XTT_REF environment variables let CI test a fork or branch of
// xtt itself (e.g. a pull request head) instead of bizhuka/xtt master.

import { execSync } from "node:child_process";
import { existsSync, rmSync, mkdirSync } from "node:fs";

const DEPS = [
  { name: "open-abap-core", url: "https://github.com/open-abap/open-abap-core" },
  { name: "open-abap-bal", url: "https://github.com/open-abap/open-abap-bal" },
  { name: "xtt", url: process.env.XTT_REPO ?? "https://github.com/bizhuka/xtt", ref: process.env.XTT_REF },
];

mkdirSync("deps", { recursive: true });

for (const dep of DEPS) {
  const dir = `deps/${dep.name}`;
  if (existsSync(dir)) {
    if (process.env.FORCE_DEPS !== "1") {
      console.log(`[deps] ${dep.name}: exists, skipping`);
      continue;
    }
    rmSync(dir, { recursive: true, force: true });
  }
  const branch = dep.ref ? `--branch ${dep.ref}` : "";
  console.log(`[deps] cloning ${dep.url} ${dep.ref ?? ""}`);
  execSync(`git clone --quiet --depth 1 ${branch} ${dep.url} ${dir}`, { stdio: "inherit" });
}

console.log("[deps] done");
