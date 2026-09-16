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
| 022  | DOCX tree `{R-T;group=_GROUP1}`: `;func=SUM/FIRST` subtotals, `;merge=G0`, `;cond=sy-tabix` (asserted exactly) |
| 030  | two root blocks `{DOC-…}` + `{R-…}`, `R` as a table of roots — one cloned sheet per entry |
| 030_b | `;merge=X` on a sheet that carries no `<mergeCells>` yet — xtt adds the element through `if_ixml_node~insert_child` (open-abap-core#1243) |
| 060  | relation tree `{R-T;group=DIR-PAR_DIR}` + the static `PREPARE_TREE` event |

One template per test — 12 of the 64 templates in `deps/xtt/src/demo/`.

The demo *programs* are still not built. Upstream now ships the demos as
global classes (`zcl_xtt_demo_NNN`, driven by `zcl_xtt_open_report~web_generate`),
but running them here would take more than the classes: the demo base class
references `cl_gui_alv_grid` and `lvc_*` types, templates are read through
`zcl_xtt_file_smw0` (`WWWDATA`) by default, demo 022 selects from
`spfli`/`sflight`, and the demo data is random, so aggregates could not be
asserted exactly. The suite ports `set_merge_info` by hand with deterministic
data instead.

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
  upstreamed + a few compat DDIC elements; each file is pinned to the upstream
  version it was taken from in `tools/patches-upstream.json`, and the build
  stops when upstream changes that file instead of silently reverting it),
  hoists block-local `DATA` declarations
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

## Known gaps

`;cond=` works through xtt's own expression parser — test 022 asserts
`;cond=sy-tabix`. A condition the parser cannot handle falls back to
`PERFORM (form) IN PROGRAM (prog)` in the calling report; that path is not
exercised here.

## License

MIT for the harness code. xtt itself is Apache-2.0 by Birzhan Moldabayev,
the open-abap libraries are MIT by their authors.
