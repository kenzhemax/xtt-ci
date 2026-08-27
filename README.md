# xtt-ci

Runs [bizhuka/xtt](https://github.com/bizhuka/xtt) on the
[abaplint transpiler](https://github.com/abaplint/transpiler) stack —
**no SAP system required**. The suite exercises the engine end-to-end on the
author's own demo templates (`src/demo/*.w3mi.data.*`):

| Demo | Feature |
|---|---|
| 050  | tree markers `{R-T;group=;level=N}` + `;func=SUM/AVG/COUNT` (aggregates asserted exactly) |
| 021  | formulas, autoFilter tables, second root block `{A-INFO}` |
| 080  | `;direction=column` + code-side `tree_create` (`REF TO data`) |
| 010  | DOCX: markers broken across `<w:r>` runs, unicode |
| 110  | images `{R-T-RAW;type=image}` → `xl/media` + drawing + rels |
| 010  | HTML: same root, plain-text output (`zcl_xtt_html`) |
| 020  | SpreadsheetML: `PageSetup` header/footer, `ss:Type` cell typing (`zcl_xtt_excel_xml`) |
| 020  | WordprocessingML: numeric/date field merge (`zcl_xtt_word_xml`) |
| 022  | DOCX cell merging `;merge=G0` (asserted on `<w:vMerge>`) |
| 030  | two root blocks — `{DOC-…}` and `{R-…}` — merged into one document |
| 060  | relation tree `{R-T;group=DIR-PAR_DIR}` + the static `PREPARE_TREE` event |

One template per test — 11 of the 64 templates in `deps/xtt/src/demo/`.

The demo *programs* are deliberately not built. They are not 30 test programs
but one GUI application: `z_xtt_demo` is a single `REPORT` assembled from 26
`INCLUDE`s of **local** `lcl_demo_*` classes (no public class anywhere), it
resolves templates through `zcl_xtt_file_smw0` (`SELECT` from `WWWDATA`), and
it is driven by a selection screen with F4. The reusable half is
`set_merge_info`, which this suite ports by hand.

## Run locally

```
npm install
npm run ci          # = deps + build + suite
```

Expected final line: `ALL XTT SUITE TESTS PASSED`.

To test a fork/branch of xtt: `XTT_REPO=... XTT_REF=... npm run deps` (CI
exposes the same via workflow_dispatch inputs).

## How it works

- `tools/fetch-deps.mjs` clones xtt and the two open-abap libraries it needs (core, bal) into `deps/`
- `tools/build.mjs` downports modern ABAP to 7.02 (abaplint `--fix`), applies
  the patch overlay from `tools/patches/` (open-abap-core gaps that are being
  upstreamed + a few compat DDIC elements), hoists block-local `DATA` declarations
  (transpiler scoping workaround - `NO_HOIST=1` re-checks whether the
  transpiler bug is fixed), then transpiles everything to JavaScript.
  The ANCHORED FIXUPS list in build.mjs is currently EMPTY - upstream now
  guards every SAP-GUI-only spot itself. The machinery stays because it fails
  loudly when an anchor moves, so an upstream update can never be silently
  reverted
- `compat/eui/` is a minimal reimplementation of the
  [bizhuka/eui](https://github.com/bizhuka/eui) surface xtt needs
  (`zcl_eui_conv`, `zcl_eui_file`, `zif_eui_ole`, logger, exceptions)
- `src/zprograms/zr_xtt_suite.prog.abap` is plain ABAP — the same code would
  run on a real SAP system
- `tools/run.mjs` executes it on Node.js with an in-memory SQLite database

## Not supported

`;cond=` needs `GENERATE SUBROUTINE POOL`, which cannot exist in a
transpiled environment.

## Known gaps

Trees in DOCX do not run. `lcl_tree_handler` reaches the private
`zcl_xtt_xml_base~do_merge` through `LOCAL FRIENDS`, which the transpiler
implements as a flat `FRIENDS_ACCESS_INSTANCE` map that is **not** searched up
the inheritance chain: on a `zcl_xtt_word_docx` instance the map holds only
`SUPER` plus the subclass's own members, so the call dies with
`FRIENDS_ACCESS_INSTANCE.do_merge is not a function`. Trees in XLSX are fine —
`zcl_xtt_excel_xlsx` has its own handler. This is why demo 022 is covered with
`022_g0-docx` (cell merging) instead of `022_g0_tree-docx`.

Merging a root block passed as a **table** of roots — the template clones one
sheet per entry — crashes in `_workbook_write_xml`. Demo 030 is therefore
covered with a single `R` root, which still exercises the two-root
(`{DOC-…}` + `{R-…}`) merge.

`;type=datetime` in SpreadsheetML renders as garbage.
`zcl_xtt_excel_xml~on_match_found` splits a `char14` with
`ASSIGN <lv_string>(8) TO <lv_date> CASTING`, and the transpiler does not
reinterpret the bytes, so `lv_date`/`lv_time` come out as junk. The ABAP is
valid — this is a transpiler gap, not an xtt bug, and it does not affect the
typed `ss:Type="DateTime"` column path, which the suite does assert.

## License

MIT for the harness code. xtt itself is Apache-2.0 by Birzhan Moldabayev,
the open-abap libraries are MIT by their authors.
