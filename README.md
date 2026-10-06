# xtt-ci

Runs [bizhuka/xtt](https://github.com/bizhuka/xtt) on the
[abaplint transpiler](https://github.com/abaplint/transpiler) stack —
**no SAP system required**. Three layers of tests:

1. **xtt's own ABAP Unit tests** (`zcl_xtt*.clas.testclasses.abap`, 91 methods:
   the `;cond=` expression evaluator, formula shifting, HTML/XML output, the
   demo template maker).
   `npm test` runs every method; a failure does not stop the run.
   Tests that cannot pass here are listed with the reason in
   `tools/unit-known-failures.json`; the run fails on any other failure and on
   a listed test that passes again, so the list never goes stale.
2. **The feature suite** `zr_xtt_suite`, end-to-end on the author's own demo
   templates (`src/demo/*.w3mi.data.*`):

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
| 200  | markers in inline-string cells (`t="inlineStr"`, as openpyxl writes them) |
| 201  | absolute relationship targets (`/xl/worksheets/...`): reported as GAP, not asserted, until upstream handles them (bizhuka/xtt#21) |

One template per test — 12 of the 64 templates in `deps/xtt/src/demo/`
(200 and 201 patch the 010 template on the fly). The suite ports
`set_merge_info` by hand with deterministic data, because the demo classes
fill theirs with random values and aggregates could not be asserted exactly.

3. **Every demo with every template** — `zr_xtt_make_all` calls
   `zcl_xtt_open_report->make_all( )`, the same entry point the author's web
   demo [bizhuka/open-abap-xtt](https://github.com/bizhuka/open-abap-xtt) uses:
   22 demo classes, 64 templates (XLSX, DOCX, XML, HTML, PDF/XDP), templates
   read from `WWWDATA` through `zcl_xtt_file_smw0`, results written to
   `output/result/`. The program then checks that each template the demos
   declare produced a non-empty file. This layer proves that every template
   merges without an exception; the content is not asserted. CI uploads
   `output/result/` as the `xtt-demo-results` artifact, so the files can be
   opened in Excel or Word.

## Run locally

```
npm install
npm run ci          # = deps + build + unit tests + suite
```

Expected: `ALL XTT UNIT TESTS PASSED`, then `ALL XTT SUITE TESTS PASSED`, then
as the final line `ALL XTT DEMO TEMPLATES MERGED` (`npm run make_all` alone
reruns the last layer).

To test a fork/branch of xtt: `XTT_REPO=... XTT_REF=... npm run deps` (CI
exposes the same via workflow_dispatch inputs).

## How it works

- `tools/fetch-deps.mjs` clones xtt and the open-abap libraries it needs (core, deprecated, bal) into `deps/`
- `tools/build.mjs` downports modern ABAP to 7.02 (abaplint `--fix`), applies
  the patch overlay from `tools/patches/` (open-abap-core gaps that are being
  upstreamed + a few compat DDIC elements; each file is pinned to the upstream
  version it was taken from in `tools/patches-upstream.json`, and the build
  stops when upstream changes that file instead of silently reverting it; an
  overlay file removed from `tools/patches/` is also undone in `deps/`),
  then transpiles everything to JavaScript.
  The ANCHORED FIXUPS list in build.mjs is currently EMPTY - upstream now
  guards every SAP-GUI-only spot itself. The machinery stays because it fails
  loudly when an anchor moves, so an upstream update can never be silently
  reverted
- `compat/eui/` is a minimal reimplementation of the
  [bizhuka/eui](https://github.com/bizhuka/eui) surface xtt needs
  (`zcl_eui_conv`, `zcl_eui_file`, `zif_eui_ole`, logger, exceptions)
- `compat/sap/` holds our own minimal stand-ins for the SAP objects xtt and
  its demos touch: tables `T005X`, `T005T`, `T006A`, `T247`, `WWWDATA`,
  `SCARR`/`SPFLI`/`SFLIGHT`, `ICON`, `PA0002`, a few structures and data
  elements, the BDS and Adobe Forms classes as empty stubs (OAOR finds no
  documents, `cl_fp` returns no PDF, so `zcl_xtt_pdf` hands back the XDP), and
  `MONTH_NAMES_GET` (function group `ZSAPCOMPAT`, reads `T247`).
  `compat/sap/data/<table>.json` seeds those tables with invented sample rows
  when the database is set up, only while a table is empty
- `compat/gui/` holds the ALV pieces the demo base class references
  (`lvc_*` types, `stb_button`, a `cl_gui_alv_grid` with just the
  `user_command` event). localABAP does not use it: it gets the real ones from
  open-abap-gui
- `tools/patch-runtime.mjs` patches `@abaplint/runtime` in `node_modules`
  until the fix ships upstream: a `?=` down cast to a *local* class was never
  checked, so no `CX_SY_MOVE_CAST_ERROR` was raised and the wrong object got
  through. xtt's `;cond=` evaluator relies on that exception (unit test
  `DEMO_USER_FORMATS`, demo 130). The build stops if the patched code changes
  upstream
- MIME objects (`*.w3mi.data.*`, the demo templates) are copied to `output/`
  byte for byte, so `WWWDATA_IMPORT` from open-abap-core returns the original
  file
- `src/zprograms/` (`zr_xtt_suite`, `zr_xtt_make_all`) is plain ABAP — the
  same code would run on a real SAP system
- `tools/run.mjs` executes it on Node.js with an in-memory SQLite database

## Known gaps

Four unit tests are listed in `tools/unit-known-failures.json`. Two are xtt
bugs on the `sy-saprl = 'OPEN'` path and fail the same way in
bizhuka/open-abap-xtt (`DEMO_INVALID_OPERANDS`, `BOOLEAN_RESULTS`). Two are
`@abaplint/runtime` gaps with `ASSIGN ... CASTING` to deep types
(`_GET_STRUCTURE`, `_GET_ONE_LINE_TABLE` of the template maker; the
open-abap-xtt runner skips methods starting with `_`).

The demo programs `z_xtt_demo*`, `zcl_xtt_file_grid` and the error-repair
program are not built: they need the SAP GUI.

`;cond=` works through xtt's own expression parser — test 022 asserts
`;cond=sy-tabix`. A condition the parser cannot handle falls back to
`PERFORM (form) IN PROGRAM (prog)` in the calling report; that path is not
exercised here.

## License

MIT for the harness code. xtt itself is Apache-2.0 by Birzhan Moldabayev,
the open-abap libraries are MIT by their authors. The sample rows in
`compat/sap/data/` are invented.
