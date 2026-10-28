# abap-sqlite

A pure ABAP implementation of the SQLite database engine. It reads and writes the
[SQLite file format](https://www.sqlite.org/fileformat2.html), so databases can move
between this implementation and real SQLite. All storage goes through one regular
transparent ABAP table: no application server file system, no kernel calls, no native code.

See [PLAN.md](PLAN.md) for the architecture, the milestones and the current progress.

## Requirements

- Node.js 22 or later
- git — the transpiler clones [open-abap-core](https://github.com/open-abap/open-abap-core) when it runs
- network access (at least on the first run, to clone the dependency)

## Run the tests locally

```sh
npm install
npm test
```

`npm test` runs both layers:

| Command | What it does |
|---------|--------------|
| `npm run lint` | abaplint with the rule set in `abaplint.jsonc`, using open-abap syntax |
| `npm run unit` | transpiles `src/` to JavaScript in `output/` and runs the ABAP Unit tests on Node |

Both layers can also be run on their own. `npm run unit` empties `output/` first, so run it
again after every ABAP change; the result is only as fresh as the last transpile.

The first `npm run unit` additionally clones open-abap-core and therefore takes longer than
later runs.

## Debugging

Set `SQLITE_TRACE=1` to log every statement the transpiler sends to its SQLite database
(see `test/setup.mjs`).

```sh
SQLITE_TRACE=1 npm run unit
```

## Performance baseline

M0.7 measures the transpiler and the SQLite client, not the engine yet. Runs on
Node v22.18.0, Windows 11 (x64), in-memory SQLite:

| Operation | Count | Total | Per operation |
|-----------|-------|-------|---------------|
| `xstring` slice, 4 bytes (`lv_data+off(4)`) | 10,000 | 13–18 ms | 1.3–1.8 µs |
| table row write, 512 bytes (`MODIFY ... FROM TABLE`) | 1,000 | 29–31 ms | ~30 µs |
| table row read, 512 bytes (`SELECT ... INTO TABLE`) | 1,000 | 7–9 ms | 7–9 µs |

```sh
npm run benchmark
```

reproduces the numbers from `zcl_sqlite_benchmark`. The loops are ABAP, the timing uses
`GET RUN TIME FIELD` around the operation only: building the 1,000 input rows, `COMMIT WORK`
and the cleanup are outside the measured section. Run-to-run noise is around ±20%; treat these
as order-of-magnitude numbers for Phase 8.

## CI

`.github/workflows/test.yml` runs `npm ci` and `npm test` on every push and pull request.
