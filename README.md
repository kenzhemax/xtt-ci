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

One template per test — 8 of the 64 templates in `deps/xtt/src/demo/`. The last
three exist because `zcl_xtt_html`, `zcl_xtt_excel_xml` and `zcl_xtt_word_xml`
were being transpiled on every build but never executed.

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

`;type=datetime` in SpreadsheetML renders as garbage.
`zcl_xtt_excel_xml~on_match_found` splits a `char14` with
`ASSIGN <lv_string>(8) TO <lv_date> CASTING`, and the transpiler does not
reinterpret the bytes, so `lv_date`/`lv_time` come out as junk. The ABAP is
valid — this is a transpiler gap, not an xtt bug, and it does not affect the
typed `ss:Type="DateTime"` column path, which the suite does assert.

## License

MIT for the harness code. xtt itself is Apache-2.0 by Birzhan Moldabayev,
the open-abap libraries are MIT by their authors.
