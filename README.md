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
  (transpiler scoping workaround), then transpiles everything to JavaScript.
  The three SAP-GUI-only spots in xtt (OLE download tail, dynamic debug hook,
  BAL pushbutton) are neutralized by ANCHORED FIXUPS in build.mjs: if upstream
  xtt changes that code, the build fails with a clear message instead of
  silently reverting the author's changes
- `compat/eui/` is a minimal reimplementation of the
  [bizhuka/eui](https://github.com/bizhuka/eui) surface xtt needs
  (`zcl_eui_conv`, `zcl_eui_file`, logger, exceptions)
- `src/zprograms/zr_xtt_suite.prog.abap` is plain ABAP — the same code would
  run on a real SAP system
- `tools/run.mjs` executes it on Node.js with an in-memory SQLite database

## Not supported

`;cond=` needs `GENERATE SUBROUTINE POOL`, which cannot exist in a
transpiled environment.

## License

MIT for the harness code. xtt itself is Apache-2.0 by Birzhan Moldabayev,
the open-abap libraries are MIT by their authors.
