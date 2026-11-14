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

## Usage

`ZCL_SQLITE_DATABASE` is the public entry point. Its default VFS stores each
database in transparent table `ZSQLITE_FILES`, so the application server file
system is not involved.

```abap
DATA lo_database TYPE REF TO zcl_sqlite_database.

lo_database = zcl_sqlite_database=>open( 'demo.db' ).

lo_database->exec(
  'CREATE TABLE items (' &&
  ' id INTEGER PRIMARY KEY,' &&
  ' name TEXT NOT NULL,' &&
  ' qty INTEGER NOT NULL DEFAULT 0,' &&
  ' price REAL)' ).
```

`open` creates the file unless `iv_create = abap_false`; pass `io_vfs` to use a
different store. Call `close( )` when you are done.

Run one statement with `execute`, or a script with `exec`. Outside a transaction
both autocommit through the pager:

```abap
lo_database->execute(
  'INSERT INTO items (id, name, qty, price) VALUES (1, ''apple'', 3, 0.5)' ).

lo_database->exec(
  'UPDATE items SET qty = qty + 1;' &&
  'DELETE FROM items WHERE qty = 0' ).
```

Use prepared statements for repeated DML. Bindings are one-based, and the
statement can be reset and run again:

```abap
DATA lo_statement TYPE REF TO zif_sqlite_statement.

lo_statement = lo_database->prepare(
  'UPDATE items SET qty = qty + ? WHERE name = ?' ).
lo_statement->bind(
  iv_index = 1
  io_value = zcl_sqlite_value=>integer( 2 ) ).
lo_statement->bind(
  iv_index = 2
  io_value = zcl_sqlite_value=>text( 'apple' ) ).
lo_statement->step( ).
```

For typed access, `insert_table` bulk inserts an internal table, and
`select_into` fills one by matching result columns to row components by name.
Both convert the common ABAP types (`i`, `int8`, `p`, `f`, `c`, `n`, `string`,
`d`, `t`, `x`, `xstring`). SQL `NULL` becomes the initial value; a result column
without a matching component is ignored.

```abap
TYPES: BEGIN OF ty_item,
         id    TYPE i,
         name  TYPE string,
         qty   TYPE i,
         price TYPE p LENGTH 8 DECIMALS 2,
       END OF ty_item.
TYPES ty_items TYPE STANDARD TABLE OF ty_item WITH DEFAULT KEY.

DATA lt_items  TYPE ty_items.
DATA lt_report TYPE ty_items.
DATA ls_item   TYPE ty_item.

ls_item-id = 2.
ls_item-name = 'banana'.
ls_item-qty = 4.
ls_item-price = '0.25'.
APPEND ls_item TO lt_items.

lo_database->insert_table(
  iv_table_name = 'items'
  it_data       = lt_items ).

lo_database->select_into(
  EXPORTING
    iv_sql   = 'SELECT id, name, qty, price FROM items ORDER BY id'
  CHANGING
    ct_table = lt_report ).
```

Transactions use `begin( )`, `commit( )` and `rollback( )`. `insert_table`
joins the caller's transaction when one is active; otherwise it commits its own
batch.

```abap
lo_database->begin( ).
lo_database->execute( 'DELETE FROM items' ).
lo_database->rollback( ).
```

`query` returns the raw result with columns and dynamically typed values, and
`plan_dump` returns the chosen query plan. Errors raise `zcx_sqlite_error`; its
`code` uses the SQLite result codes in `zcx_sqlite_error` and `message` carries
the text.

The complete running example is `src/zsqlite_demo.prog.abap`:

```sh
npm run demo
```

It prints:

```text
Items after the prepared update
1 apple 5 0.50
2 banana 4 0.25
3 cherry 1 2.00
Total value: 5.50
Rows after rollback: 3
```

The same API calls are covered by the ABAP Unit tests in
`src/api/zcl_sqlite_database.clas.testclasses.abap`.

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
