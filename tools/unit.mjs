// Runs the ABAP Unit tests the transpiler wrote into output/ - for xtt these are
// Birzhan's own test classes (zcl_xtt*.clas.testclasses.abap).
//
// output/index.mjs (the transpiler's runner) stops at the first failure and a
// JS error inside a test aborts output/_unit_open.mjs too, so this runner takes
// the same test list from index.mjs and runs every method on its own.
//
// tools/unit-known-failures.json lists tests that are expected to fail here,
// each with the reason. Exit code 1 when a test outside that list fails, or
// when a listed test passes (then the entry is stale and must be removed).
//
//   node tools/unit.mjs            all tests
//   node tools/unit.mjs ZCL_XTT_COND   only classes whose name contains the filter

import { readFileSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const OUT = resolve("output");
const KNOWN_FILE = "tools/unit-known-failures.json";
const filter = (process.argv[2] ?? "").toUpperCase();

const index = readFileSync(join(OUT, "index.mjs"), "utf8");
const body = index.match(/function getData\(\) \{([\s\S]*?\n)\}/);
if (!body) throw new Error("[unit] getData() not found in output/index.mjs - transpiler changed its runner");
const getData = new Function(body[1]);

const known = existsSync(KNOWN_FILE) ? JSON.parse(readFileSync(KNOWN_FILE, "utf8")) : {};

// The SAP user profile the tests were written for: |{ d DATE = USER }| gives
// 06.11.2020 and TIME = USER gives 15:26:35. The runtime formats these with
// Intl's "default" locale, i.e. the machine locale (en-US: 11/06/2020 03:26:35 PM),
// so pin it here, the same way the tests pin sy-datum. Works on Windows too,
// where LC_ALL does not reach ICU.
const USER_LOCALE = "de-DE";
const NativeDateTimeFormat = Intl.DateTimeFormat;
function UserDateTimeFormat(locales, options) {
  const loc = (locales === undefined || locales === "default") ? USER_LOCALE : locales;
  return new NativeDateTimeFormat(loc, options);
}
UserDateTimeFormat.prototype = NativeDateTimeFormat.prototype;
UserDateTimeFormat.supportedLocalesOf = NativeDateTimeFormat.supportedLocalesOf;
Intl.DateTimeFormat = UserDateTimeFormat;

await import(pathToFileURL(join(OUT, "init.mjs")).href);

function describe(err) {
  if (err === undefined || err === null) return String(err);
  if (err instanceof Error) {
    const at = (err.stack ?? "").split("\n").find((l) => l.includes(".abap:") || l.includes(".mjs:"));
    return `${err.constructor.name}: ${err.message}${at ? " " + at.trim() : ""}`;
  }
  // ABAP exception object: class name + get_text( ) when available
  const name = err.constructor?.name ?? "exception";
  return name;
}

async function abapText(err) {
  try {
    // kernel_cx_assert (cl_abap_unit_assert) carries expected/actual/msg
    if (err && err.expected && err.actual && typeof err.actual.get === "function") {
      const msg = err.msg?.get?.() ?? "";
      return `expected <${err.expected.get()}> actual <${err.actual.get()}>${msg ? " " + msg : ""}`;
    }
    if (err && typeof err.if_message$get_text === "function") {
      return (await err.if_message$get_text()).get();
    }
    if (err && typeof err.get_text === "function") return (await err.get_text()).get();
  } catch { /* fall through */ }
  return "";
}

const results = [];
for (const st of getData()) {
  if (filter && !st.objectName.includes(filter)) continue;
  const imported = await import(pathToFileURL(join(OUT, st.filename)).href);
  const localClass = imported[st.localClass];
  try {
    if (localClass.class_setup) await localClass.class_setup();
  } catch (err) {
    for (const m of st.methods) {
      results.push({ id: `${st.objectName}/${st.localClass.toUpperCase()}->${m.name.toUpperCase()}`,
                     ok: false, message: "class_setup: " + describe(err) });
    }
    continue;
  }
  for (const m of st.methods) {
    const id = `${st.objectName}/${st.localClass.toUpperCase()}->${m.name.toUpperCase()}`;
    if (m.skip) continue;
    const started = Date.now();
    try {
      const test = await (new localClass()).constructor_();
      const inst = test.FRIENDS_ACCESS_INSTANCE;
      if (test.setup) await test.setup();
      if (inst.setup) await inst.setup();
      if (inst.SUPER && inst.SUPER.setup) await inst.SUPER.setup();
      await inst[m.name]();
      if (test.teardown) await test.teardown();
      if (inst.teardown) await inst.teardown();
      if (inst.SUPER && inst.SUPER.teardown) await inst.SUPER.teardown();
      results.push({ id, ok: true, ms: Date.now() - started });
    } catch (err) {
      const text = await abapText(err);
      results.push({ id, ok: false, ms: Date.now() - started,
                     message: describe(err) + (text ? ": " + text : "") });
    }
  }
  try {
    if (localClass.class_teardown) await localClass.class_teardown();
  } catch { /* reported by the tests themselves */ }
}

let unexpected = 0;
let stale = 0;
for (const r of results) {
  const reason = known[r.id];
  if (r.ok && reason) {
    stale++;
    console.log(`STALE  ${r.id} passes now - remove it from ${KNOWN_FILE}`);
  } else if (r.ok) {
    console.log(`ok     ${r.id}`);
  } else if (reason) {
    console.log(`known  ${r.id} (${reason})`);
  } else {
    unexpected++;
    console.log(`FAIL   ${r.id}\n       ${r.message}`);
  }
}
const passed = results.filter((r) => r.ok).length;
const knownFailed = results.filter((r) => !r.ok && known[r.id]).length;
console.log(`\n[unit] ${results.length} tests: ${passed} passed, ${knownFailed} known failures, ` +
            `${unexpected} unexpected failures, ${stale} stale known failures`);
if (unexpected === 0 && stale === 0) console.log("ALL XTT UNIT TESTS PASSED");
process.exit(unexpected === 0 && stale === 0 ? 0 : 1);
