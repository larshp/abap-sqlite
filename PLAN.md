# PLAN: SQLite in ABAP

A pure ABAP implementation of the SQLite database engine. It reads and writes the
[SQLite file format](https://www.sqlite.org/fileformat2.html), so files can move between this
implementation and real SQLite. All file storage goes through **one regular transparent ABAP
database table**. No application server file system, no kernel calls, no native code.

## Goals

- **File format compatibility.** A database written by `abap-sqlite` opens in `sqlite3` and passes
  `PRAGMA integrity_check`, and the reverse also holds (within the supported feature set).
- **Persistence in an ABAP table.** Every "file" (the database, plus any auxiliary files) is stored
  as fixed size blocks in one transparent table. Everything above the storage layer only sees a
  VFS interface.
- **Runs anywhere ABAP runs.** It is developed and tested on Node.js through the
  [abaplint transpiler](https://github.com/abaplint/transpiler) and
  [open-abap](https://github.com/open-abap/open-abap-core). It stays portable to real SAP systems.
- **Tested against the real thing.** Results are compared with `sql.js` (SQLite compiled to
  WASM), which is already a dependency of `@abaplint/database-sqlite`.

## Non-goals (for now)

- WAL mode and shared memory (`-wal`, `-shm` files)
- Virtual tables, FTS, R-Tree, JSON1, loadable extensions
- Multiple processes sharing a page cache. Each ABAP session has its own pager.
- Full `VACUUM`, `ATTACH DATABASE`, triggers, window functions (candidates for Phase 10)
- Raw performance on par with C SQLite

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│ Public API      ZCL_SQLITE_DATABASE / ZIF_SQLITE_STATEMENT │
├──────────────────────────────────────────────────────────┤
│ SQL front end   Tokenizer → Parser → AST                 │
│                 Resolver / Planner → operator tree       │
├──────────────────────────────────────────────────────────┤
│ Executor        Iterator operators (scan, filter, sort,  │
│                 aggregate, join, insert, update, delete) │
│                 Expression evaluator, affinity, collation│
├──────────────────────────────────────────────────────────┤
│ Schema          sqlite_schema reader/writer, catalog     │
├──────────────────────────────────────────────────────────┤
│ Record          Record format encode/decode (serial types)│
├──────────────────────────────────────────────────────────┤
│ B-tree          Table & index b-trees, cursors, overflow,│
│                 insert/split/balance, delete, freelist   │
├──────────────────────────────────────────────────────────┤
│ Pager           Page cache, dirty tracking, transactions,│
│                 header (page 1), change counter, locking │
├──────────────────────────────────────────────────────────┤
│ VFS             ZIF_SQLITE_VFS / ZIF_SQLITE_FILE         │
│   ├─ ZCL_SQLITE_VFS_TABLE   (persistence, ZSQLITE_FILES) │
│   └─ ZCL_SQLITE_VFS_MEMORY  (tests, temp databases)      │
└──────────────────────────────────────────────────────────┘
```

### Key design decisions

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | **Iterator-model executor over a plan tree**, not a VDBE bytecode VM | Much less code, easier to debug in ABAP. A VDBE can come later if needed. |
| D2 | **Storage unit = block, with block size = page size, at most 65536 bytes** | One page write becomes one row `MODIFY`. Partial page I/O never needs read-modify-write across rows. 64 KiB is SQLite's maximum page size, so any SQLite page fits in one block; M0.4 verified blocks from 512 B to 64 KiB. |
| D3 | **Atomicity comes from the ABAP database LUW, not a rollback journal** | The pager keeps dirty pages in memory and flushes them all in one go when SQLite commits. The flush is made durable by the caller's `COMMIT WORK` (or by the `auto_commit_work` option). This behaves like `journal_mode=MEMORY`. A crash before the DB commit leaves the table untouched. Confirmed in M0.5: `ROLLBACK WORK` discards uncommitted rows, and a row that was committed survives a later rollback. |
| D4 | **Header field byte 18/19 = 1 (legacy rollback journal)**, never WAL | So that real SQLite opens exported files without expecting a WAL. |
| D5 | **Write locking via `SELECT ... FOR UPDATE` on block 0 of the file**, plus an optional enqueue | Works on a real SAP database, which is where sessions share a file. The transpiler accepts `SELECT SINGLE ... FOR UPDATE` but drops the clause ([ANORMALIES.md](ANORMALIES.md)), so locking cannot be tested there; M0.5 only documents the syntax. Readers check the file change counter (header offset 24) to invalidate a stale page cache. |
| D6 | **The 64-bit integer type is `int8`** | SQLite rowids and INTEGER values are signed 64-bit. Verified in M0.6. |
| D7 | **Text is UTF-8 only at first** (`PRAGMA encoding = 'UTF-8'`) | Conversion uses `CL_ABAP_CONV_CODEPAGE` (present in open-abap-core). UTF-16 databases are readable in a later milestone. |
| D8 | **Object prefix `ZCL_SQLITE_` / `ZIF_SQLITE_` / `ZCX_SQLITE_`** | Customer namespace, so it can be installed with abapGit anywhere. |
| D9 | **Target language version: open-abap syntax, 7.50 compatible. 7.50 is the minimum release, with no downport to older releases.** Steampunk / ABAP Cloud is checked in M9.3. | Keeps the code portable. abaplint enforces it. |

### The persistence table

`ZSQLITE_FILES`, a transparent table with delivery class `A`:

| Field | Key | Type | Notes |
|-------|-----|------|-------|
| `MANDT` | X | `MANDT` | Client |
| `FILENAME` | X | `CHAR 200` | Logical file name, e.g. `MYAPP/orders.db`. Auxiliary files use suffixes (`-journal`, if ever used). |
| `BLOCKNO` | X | `INT4` | 0-based block number |
| `DATA` | | `RAWSTRING` | Block content. Every block is exactly *block size* bytes, except possibly the last one. |

- File size = `max(BLOCKNO) * block_size + xstrlen( last block )`. For a SQLite database the
  size is always a multiple of the page size.
- The block size is fixed per file when the file is created (the default is 4096, the SQLite
  default page size). For the main database file it equals the page size from the header.
- `truncate` deletes rows with `BLOCKNO >= n` and trims the last block.
- Listing, deleting, copying and renaming files are VFS operations on this table.
- Import/export of a complete file as `xstring` (`ZCL_SQLITE_VFS_TABLE=>export( )` / `import( )`)
  lets you upload or download a real `.db` file.

---

## Repository layout (target)

```
abap-sqlite/
├─ .github/workflows/test.yml
├─ abaplint.jsonc
├─ abap_transpile.json
├─ package.json
├─ PLAN.md
├─ ANORMALIES.md     abaplint / transpiler bugs and workarounds
├─ src/
│  ├─ ddic/zsqlite_files.tabl.xml
│  ├─ vfs/        zif_sqlite_vfs, zif_sqlite_file, zcl_sqlite_vfs_table, zcl_sqlite_vfs_memory
│  ├─ util/       zcl_sqlite_bytes (BE ints, varint, float64), zcl_sqlite_utf8
│  ├─ pager/      zcl_sqlite_pager, zcl_sqlite_header
│  ├─ btree/      zcl_sqlite_btree, zcl_sqlite_cursor, zcl_sqlite_index_cursor, zcl_sqlite_page, zcl_sqlite_freelist
│  ├─ record/     zcl_sqlite_record, zcl_sqlite_value
│  ├─ schema/     zcl_sqlite_schema, zcl_sqlite_catalog
│  ├─ sql/        zcl_sqlite_tokenizer, zcl_sqlite_parser, zcl_sqlite_ast_*
│  ├─ exec/       zcl_sqlite_planner, zcl_sqlite_op_*, zcl_sqlite_expr_eval, zcl_sqlite_functions
│  ├─ api/        zcl_sqlite_database, zif_sqlite_statement, zcx_sqlite_error
│  └─ zsqlite.devc.xml
└─ test/
   ├─ setup.mjs           DB connection + fixture loading into ZSQLITE_FILES
   ├─ fixtures/           *.db generated by sql.js + expected results (*.json)
   ├─ tools/              node scripts: make-fixtures.mjs, export-and-verify.mjs
   └─ (ABAP Unit tests live as .clas.testclasses.abap next to each class)
```

---

## Milestones

The work is grouped into **phases** 0–10. Each phase is split into small **milestones**
(`M<phase>.<n>`). A milestone is a few days of work at most, goes in as its own PR, and ends with
a green `npm test` (abaplint + transpiled ABAP Unit) in CI. Milestones in a phase go in order
unless noted otherwise.

### Phase 0: Tooling: abaplint and the transpiler (first step)

Goal: a running test pipeline and proof that the transpiler can do what the engine needs, before
any engine code exists. Any gap found goes into `ANORMALIES.md`.

#### M0.1 npm project and transpiler

- [x] `package.json` with `@abaplint/transpiler-cli`, `@abaplint/runtime`,
      `@abaplint/database-sqlite`, `rimraf`. Script `unit`:
      `rimraf output && abap_transpile && node output/index.mjs`
- [x] `.npmrc` (`ignore-scripts=true`), `.gitignore` (`node_modules`, `output`)
- [x] `abap_transpile.json`: `input_folder` `{src,test}`, `write_unit_tests: true`,
      `write_source_map: true`, the open-abap-core lib, and `setup` → `test/setup.mjs`
- [x] `test/setup.mjs`: connect `SQLiteDatabaseClient` as `DEFAULT`, create the schemas, insert data
- [x] Package `src/zsqlite.devc.xml` and one trivial class with one ABAP Unit test

**Done when:** `npm run unit` runs the trivial test locally and it passes.

#### M0.2 abaplint

- [x] Add `@abaplint/cli`. Scripts `lint`: `abaplint`, `test`: `npm run lint && npm run unit`
- [x] `abaplint.jsonc`: `syntax.version = "open-abap"`, a dependency on open-abap-core, and a
      strict rule set (start from open-abap-bal's config). Target-version checks come in M9.1.

**Done when:** `npm test` passes locally.

#### M0.3 CI and project docs

- [x] GitHub Actions workflow `test.yml`: checkout, setup-node, `npm install`, `npm test`
- [x] README: how to run the tests locally
- [x] Create `ANORMALIES.md` (see [Tooling bugs](#tooling-bugs-anormaliesmd))

**Done when:** CI is green on a PR.

#### M0.4 Persistence table spike

- [x] `ZSQLITE_FILES` table definition (`.tabl.xml`)
- [x] ABAP Unit: `INSERT` / `MODIFY` / `SELECT` / `DELETE` of `RAWSTRING` rows, block sizes
      512 B up to 64 KiB, `MODIFY ... FROM TABLE` for many rows

**Done when:** the tests pass, and the maximum block size is decided and written into D2.

#### M0.5 Transaction and locking spike

- [x] ABAP Unit: `SELECT ... FOR UPDATE`, `COMMIT WORK`, `ROLLBACK WORK` behaviour in the
      transpiler

**Done when:** the behaviour is documented in tests, and D3/D5 are confirmed or revised.

#### M0.6 Language feature spike

- [x] `int8` arithmetic around ±2^63 boundaries and overflow behaviour
- [x] `xstring` slicing (`xstr+off(len)`), `CONCATENATE ... IN BYTE MODE`, `BIT-AND`/`BIT-OR`/`BIT-SHIFT`
      equivalents, hex ↔ int conversion
- [x] UTF-8 encode/decode with `CL_ABAP_CONV_CODEPAGE`

**Done when:** every feature works, or its gap is recorded in `ANORMALIES.md` with a workaround
or an upstream issue.

#### M0.7 Performance baseline

- [x] Small benchmark: 10k xstring slice operations, 1k table row writes, 1k row reads

**Done when:** the numbers are written into the README or `ANORMALIES.md`, as a baseline for Phase 8.

### Phase 1: Byte utilities and VFS

#### M1.1 Big-endian integers

- [x] `ZCL_SQLITE_BYTES`: read/write u8, u16, u24, u32, u48, i64 from/to `xstring` at an offset

**Done when:** round trips and boundary values are tested.

#### M1.2 Varints

- [x] SQLite varint encode/decode (1–9 bytes, the 9th byte uses all 8 bits), and varint length

**Done when:** the known vectors from the SQLite docs pass, including negative numbers (9 bytes).

#### M1.3 Float64

- [x] IEEE 754 float64 ↔ `f` conversion (big-endian), handling ±0, ±inf, NaN and subnormals

**Done when:** test vectors produced by sql.js/Node (`DataView`) pass.

#### M1.4 UTF-8

- [x] `ZCL_SQLITE_UTF8`: string ↔ UTF-8 xstring and byte length

**Done when:** ASCII, multi-byte and 4-byte (surrogate pair) characters round-trip.

#### M1.5 VFS interfaces and memory VFS

- [x] `ZIF_SQLITE_VFS`: `open( name ) → file`, `exists`, `delete`, `list`, `rename`
- [x] `ZIF_SQLITE_FILE`: `read( offset, amount ) → xstring` (short reads are zero-filled and
      flagged), `write( offset, data )`, `truncate( size )`, `size( )`, `sync( )`,
      `lock( level )` / `unlock( level )`, `close( )`
- [x] `ZCL_SQLITE_VFS_MEMORY`: blocks in an internal table. `lock` does nothing.
- [x] A shared VFS contract test suite (an abstract test class that any VFS can reuse)

`read` returns `ZIF_SQLITE_FILE=>TY_READ_RESULT` (`data` and `short`) so the zero-filled bytes and
the short-read flag travel together. The shared suite is `ZCL_SQLITE_VFS_CONTRACT`; a VFS test
class inherits it and implements `CREATE_VFS`. Offsets and sizes are `i` (a 2 GB file limit),
matching `xstrlen` and the `INT4` block number in `ZSQLITE_FILES`.

**Done when:** the memory VFS passes the contract tests.

#### M1.6 Table VFS: file I/O

- [x] `ZCL_SQLITE_VFS_TABLE` on top of `ZSQLITE_FILES`: read, write, truncate, size, with a block
      cache. Writes that cross block boundaries are split.

**Done when:** the table VFS passes the same contract tests.

#### M1.7 Table VFS: file management

- [x] `exists`, `delete`, `list`, `rename`
- [x] `import( name, xstring )` / `export( name ) → xstring`

**Done when:** a file can be imported, listed, renamed, exported byte-identical, and deleted.

### Phase 2: File format: read-only

#### M2.1 Fixture pipeline

- [x] `test/tools/make-fixtures.mjs` (uses sql.js) writes `.db` files and the expected contents as
      JSON. Start with two fixtures: an empty DB and one small table.
- [x] `test/setup.mjs` loads the fixtures into `ZSQLITE_FILES` (split into blocks) before the tests run
- [x] Fixtures are committed under `test/fixtures`; CI uses the checked-in files. Run
      `npm run fixtures` to regenerate them.

**Done when:** an ABAP Unit test can `export( )` a fixture, and its bytes equal the `.db` file.

#### M2.2 Database header

- [x] `ZCX_SQLITE_ERROR` with SQLite-like result codes (`SQLITE_NOTADB`, `SQLITE_CORRUPT`, …)
- [x] `ZCL_SQLITE_HEADER`: parse and validate the 100-byte header (magic, page size encoding
      `1 = 65536`, reserved bytes, change counter, schema cookie, text encoding, freelist, …)

**Done when:** the fixture headers parse to the values `PRAGMA`s report in sql.js. Bad magic and
a bad page size raise errors.

#### M2.3 Read-only pager

- [x] `ZCL_SQLITE_PAGER`: fetch a page by number, LRU page cache, page 1 offset quirk (100 bytes);
      `three_pages.db` fixture for cache eviction tests

**Done when:** pages can be fetched, and cache hits and evictions are tested.

#### M2.4 B-tree pages

- [x] `ZCL_SQLITE_PAGE`: b-tree page header, cell pointer array, the 4 page types
      (table/index × leaf/interior), right-most pointer, freeblocks; `indexed.db`
      fixture covers all 4 page types

**Done when:** every page in the fixtures is classified and its cell count is correct.

#### M2.5 Records and values

- [x] `ZCL_SQLITE_VALUE`: dynamic value type (NULL / INTEGER / REAL / TEXT / BLOB)
- [x] `ZCL_SQLITE_RECORD`: decode the record header and serial types 0–9, ≥12 (blob), ≥13 (text)

**Done when:** a fixture with every serial type decodes correctly.

#### M2.6 Table cursor

- [x] `ZCL_SQLITE_CURSOR` for table b-trees: `first`, `next`, `seek( rowid )`, across
      multi-level trees (no overflow yet)

**Done when:** a 10k-row fixture is scanned in rowid order, and point seeks work.

#### M2.7 Overflow pages

- [x] Local payload size calculation (`X`, `M`, `K` formulas from the spec), overflow chain reassembly

**Done when:** fixtures with large TEXT/BLOB values (just over the threshold and multi-page) decode correctly.

#### M2.8 Index cursor

- [x] Index b-tree traversal: `first`, `next`, `seek( key prefix )`. Record comparison uses
      BINARY collation for now.

**Done when:** index entries from the fixtures match the JSON and come back in index order.

#### M2.9 Raw schema

- [x] Read `sqlite_schema` (page 1) into a raw catalog: type, name, tbl_name, rootpage, sql

**Done when:** the raw catalog equals `SELECT * FROM sqlite_schema` from sql.js for all fixtures.

#### M2.10 Fixture breadth

- [x] Add fixtures: page sizes 512…65536, freelist pages, auto-vacuum (ptrmap pages),
      `WITHOUT ROWID` tables, NULLs, many indexes

**Done when:** for every fixture, all rows of all tables and indexes decode and match the JSON.

### Phase 3: SQL front end

#### M3.1 Tokenizer

- [ ] `ZCL_SQLITE_TOKENIZER`: the full SQLite token set (keywords, identifiers in `"…"`, `[…]`
      and `` `…` ``, string/blob literals `X'…'`, numbers including hex, comments, parameters
      `?`, `?NNN`, `:name`, `@name`, `$name`), with token positions

**Done when:** a token corpus passes, including edge cases (`''` escapes, `1e5`, `0x1F`, `--` at EOF).

#### M3.2 Expressions

- [ ] AST node classes and a debug dump (normalized text form)
- [ ] `ZCL_SQLITE_PARSER`: hand-written Pratt parser for expressions, following SQLite operator
      precedence: literals, columns (`schema.table.col`), unary/binary ops, `||`, `IS [NOT]`,
      `[NOT] IN (list)`, `[NOT] BETWEEN`, `[NOT] LIKE/GLOB [ESCAPE]`, `CASE`, `CAST`, function
      calls with `DISTINCT` / `*`, `COLLATE`, parameters

**Done when:** an expression corpus parses to the expected dumps, including precedence edge cases.

#### M3.3 DDL

- [ ] `CREATE TABLE` (column defs, type names, constraints, table constraints, `WITHOUT ROWID`,
      `IF NOT EXISTS`), `CREATE [UNIQUE] INDEX`, `DROP TABLE/INDEX`

**Done when:** every `CREATE` statement in the fixtures parses.

#### M3.4 SELECT core

- [ ] Result columns, `*`, `t.*`, aliases, `FROM` with joins (`INNER`, `LEFT`, `CROSS`, `,`),
      `WHERE`, `GROUP BY`, `HAVING`, `ORDER BY`, `LIMIT/OFFSET`, `DISTINCT`, `VALUES`

**Done when:** a SELECT corpus parses to the expected dumps.

#### M3.5 SELECT advanced

- [ ] Compound selects, `WITH [RECURSIVE]` CTEs, subqueries in expressions (`IN (SELECT …)`,
      `EXISTS`, scalar) and in `FROM`

**Done when:** an advanced corpus parses to the expected dumps.

#### M3.6 DML

- [ ] `INSERT [OR …] INTO … VALUES / SELECT / DEFAULT VALUES`, `UPDATE`, `DELETE`
      (`UPSERT` and `RETURNING` come later)

**Done when:** a DML corpus parses to the expected dumps.

#### M3.7 Other statements and scripts

- [ ] `BEGIN`, `COMMIT`, `ROLLBACK`, `PRAGMA`, `EXPLAIN [QUERY PLAN]`, scripts with several
      statements separated by `;`

**Done when:** a script corpus splits and parses correctly.

#### M3.8 Parse errors

- [ ] Syntax errors raise `ZCX_SQLITE_ERROR` with a position and a message like SQLite's
      (`near "X": syntax error`)

**Done when:** a corpus of ~50 invalid statements fails with the expected messages, and the full
valid corpus (~200 statements) still passes.

### Phase 4: Read-only query execution

#### M4.1 Catalog

- [ ] Build table/column/index metadata from the parsed `sqlite_schema` SQL. Column affinity
      follows the type-name rules (INTEGER / TEXT / BLOB / REAL / NUMERIC). `INTEGER PRIMARY KEY`
      is a rowid alias.

**Done when:** the catalog matches `PRAGMA table_info` / `index_list` / `index_info` from sql.js.

#### M4.2 Expression evaluator

- [ ] `ZCL_SQLITE_EXPR_EVAL`: three-valued logic, integer/real arithmetic with SQLite overflow
      rules (int → real), division by zero → NULL, string ↔ number coercions, `||`, `CASE`,
      `CAST`, `IS`, `IN (list)`, `BETWEEN`, comparison with affinity rules

**Done when:** a corpus of constant expressions (`SELECT <expr>`) matches sql.js, including value types.

#### M4.3 Collations and LIKE/GLOB

- [ ] Collations `BINARY`, `NOCASE`, `RTRIM`, `COLLATE` operator. `LIKE` (ASCII case folding,
      `ESCAPE`) and `GLOB`.

**Done when:** a comparison/pattern corpus matches sql.js.

#### M4.4 First query end to end

- [ ] Iterator operator interface. Operators `TableScan`, `Filter`, `Project`.
- [ ] Minimal API (it gets more polish in Phase 6): `ZCL_SQLITE_DATABASE=>open( name )`,
      `->query( sql ) → result table of value rows`

**Done when:** `SELECT a, b + 1 FROM t WHERE c > 5` returns the right rows from a fixture.

#### M4.5 Differential test harness

- [ ] `make-fixtures.mjs` also writes `queries.json` (SQL + expected rows and types from sql.js),
      and one ABAP Unit test runs all of them and reports each mismatch

**Done when:** the harness runs in CI with the queries supported so far.

#### M4.6 Scalar functions

- [ ] `abs`, `coalesce`, `ifnull`, `nullif`, `iif`, `length`, `lower`, `upper`, `substr`,
      `trim/ltrim/rtrim`, `replace`, `instr`, `typeof`, `round`, `hex`, `quote`, `min/max`
      (scalar), `random`

**Done when:** a function corpus matches sql.js (except `random`, which is only checked by type).

#### M4.7 Sort, limit, distinct

- [ ] Operators `Sort` (multi-key, `ASC/DESC`, `NULLS FIRST/LAST`, collations), `Limit/Offset`, `Distinct`

**Done when:** an ordering corpus matches sql.js row for row.

#### M4.8 Aggregates

- [ ] `count`, `sum`, `total`, `avg`, `min`, `max`, `group_concat`, with `DISTINCT`. `GROUP BY`,
      `HAVING`, and aggregates without `GROUP BY`.

**Done when:** an aggregate corpus matches sql.js.

#### M4.9 Joins

- [ ] `NestedLoopJoin` for `INNER`, `LEFT`, `CROSS`, with `ON` / `USING` / `NATURAL`, and column
      name resolution across tables

**Done when:** a join corpus matches sql.js.

#### M4.10 Planner v1

- [ ] Rowid equality/range lookups, index use for `=`/range on a leftmost prefix, otherwise a
      full scan. A plan dump for tests.

**Done when:** plan-dump tests show index use, and the whole differential corpus (≥ 300 read
queries) still matches sql.js.

### Phase 5: Write path and transactions

#### M5.1 Pager write mode

- [ ] Dirty page tracking, copy-on-write, flush to the VFS on commit, discard on rollback (D3)
- [ ] Header maintenance: database size in pages (offset 28), file change counter (24),
      version-valid-for (92), SQLite version number (96)

**Done when:** pages changed through the pager are persisted on commit and dropped on rollback.

#### M5.2 New database and compatibility verifier

- [ ] Create a new empty database (header + empty `sqlite_schema` page)
- [ ] **Compatibility verifier** `test/tools/export-and-verify.mjs`: run the transpiled ABAP
      scenario programs, read the `ZSQLITE_FILES` rows back from the transpiler's SQLite
      connection, concatenate the blocks into a `.db`, open it in sql.js, run
      `PRAGMA integrity_check` and compare the contents. This runs as part of `npm test`.

**Done when:** an empty database created in ABAP passes `integrity_check` in sql.js.

#### M5.3 Page allocation and freelist

- [ ] Allocate pages from the freelist or by appending. Free pages onto trunk/leaf freelist pages.

**Done when:** allocate/free sequences give valid freelists (checked with sql.js
`PRAGMA freelist_count` and `integrity_check`).

#### M5.4 Record encoding and leaf insert

- [ ] `ZCL_SQLITE_RECORD` encode (smallest serial type per value)
- [ ] Table b-tree insert into a leaf with free space (cell placement, freeblocks)

**Done when:** rows inserted through the b-tree API into a fixture table read back correctly in
sql.js.

#### M5.5 Page split

- [ ] Leaf and interior splits, root split (the root page number must not change). Start with a
      simple split. A `balance_nonroot` equivalent for better fill factors can come later.

**Done when:** 10k sequential and random rowid inserts give a valid multi-level tree.

#### M5.6 Overflow writes

- [ ] Write payloads that spill onto overflow page chains

**Done when:** rows with large TEXT/BLOB values are verified in sql.js.

#### M5.7 CREATE TABLE

- [ ] Allocate the root page, write the `sqlite_schema` row, bump the schema cookie (40), reload the catalog

**Done when:** a table created in ABAP shows up correctly in sql.js.

#### M5.8 INSERT

- [ ] `INSERT … VALUES / SELECT / DEFAULT VALUES`: rowid assignment, `INTEGER PRIMARY KEY` alias,
      defaults, type affinity on store, `last_insert_rowid`, `changes`

**Done when:** a DML corpus gives identical table contents in sql.js and abap-sqlite.

#### M5.9 B-tree delete and DELETE

- [ ] Cell removal, freeblock list / fragmentation handling, defragmentation. Merging underfull
      pages is optional at first, but the tree must stay valid. Then the `DELETE` statement.

**Done when:** deleting random subsets of 10k rows passes `integrity_check`.

#### M5.10 UPDATE

- [ ] `UPDATE`, including changing the rowid / `INTEGER PRIMARY KEY`, and growing or shrinking
      records (into or out of overflow)

**Done when:** an update corpus gives identical contents in sql.js and abap-sqlite.

#### M5.11 Indexes

- [ ] Index b-tree insert/delete. `CREATE INDEX` (build from existing rows). Index maintenance
      on INSERT/UPDATE/DELETE.

**Done when:** indexes stay consistent through DML (sql.js `integrity_check`).

#### M5.12 DROP TABLE / DROP INDEX

- [ ] Free all pages of the b-tree, remove the `sqlite_schema` rows

**Done when:** the freed pages show up in the freelist, and `integrity_check` passes.

#### M5.13 Transactions and the ABAP LUW

- [ ] Autocommit per statement. `BEGIN` / `COMMIT` / `ROLLBACK`. Statement-level rollback on error.
- [ ] ABAP LUW integration: the default is to only write to the DB, and the caller owns
      `COMMIT WORK`. Option `auto_commit_work`.

**Done when:** tests cover rollback after a failed statement, an explicit `ROLLBACK`, and an
ABAP `ROLLBACK WORK` after a SQLite commit.

#### M5.14 Write locking

- [ ] Take the write lock on block 0 of the file (D5) when a write transaction starts

**Done when:** the lock is taken and released at the right points (tested through the VFS).

#### M5.15 Randomized write workloads

- [ ] Seeded random insert/update/delete workloads (10k+ ops, overflow payloads, many indexes),
      checked against sql.js every N operations

**Done when:** the workloads give files that pass `integrity_check` in sql.js and match a
reference run.

### Phase 6: Public API

#### M6.1 Prepared statements

- [ ] `prepare( sql ) → ZIF_SQLITE_STATEMENT`: `bind( index|name, value )`, `step( ) → abap_bool`,
      `column_count`, `column_name`, `column_type`, `column_value`, `reset( )`

**Done when:** a statement can be prepared once and run many times with different bindings.

#### M6.2 Database API

- [ ] `ZCL_SQLITE_DATABASE`: `open( name, vfs = table, create = abap_true )`, `close( )`,
      `exec( sql )` for multiple statements with no result, `begin( )`, `commit( )`,
      `rollback( )`, `last_insert_rowid( )`, `changes( )`
- [ ] Finalize `ZCX_SQLITE_ERROR` result codes (`SQLITE_ERROR`, `SQLITE_CONSTRAINT`,
      `SQLITE_BUSY`, `SQLITE_CORRUPT`, …) and messages

**Done when:** the minimal API from M4.4 is replaced, and all tests use the final API.

#### M6.3 ABAP conveniences

- [ ] `select_into( sql, CHANGING ct_table )`. It maps result columns onto any ABAP internal
      table by name using RTTI, with type conversion.
- [ ] `insert_table( table_name, it_data )` for bulk insert from an internal table

**Done when:** round trips of internal tables with all common ABAP types are tested.

#### M6.4 Demo and docs

- [ ] A demo program `ZSQLITE_DEMO` and a usage section in the README

**Done when:** the README examples match the tests, and the demo runs in the transpiler.

### Phase 7: SQL coverage

The order in this phase is flexible. Each milestone adds its cases to the differential corpus.

| Milestone | Scope |
|-----------|-------|
| M7.1 Column constraints | `NOT NULL`, `CHECK`, `DEFAULT` expressions, `COLLATE` on columns |
| M7.2 Unique keys | `UNIQUE`, `PRIMARY KEY` (incl. composite → autoindex `sqlite_autoindex_*`) |
| M7.3 Conflict handling | `INSERT OR REPLACE/IGNORE/ABORT/FAIL/ROLLBACK`, `ON CONFLICT` UPSERT, `RETURNING` |
| M7.4 AUTOINCREMENT | `sqlite_sequence` table |
| M7.5 WITHOUT ROWID writes | Insert/update/delete on index-organized tables |
| M7.6 Subqueries | Scalar, `IN`, `EXISTS`, correlated, subqueries in `FROM` |
| M7.7 Views | `CREATE VIEW` / `DROP VIEW`, expanded at plan time |
| M7.8 Compound selects | `UNION [ALL]`, `INTERSECT`, `EXCEPT` with `ORDER BY` / `LIMIT` |
| M7.9 CTEs | `WITH`, `WITH RECURSIVE` |
| M7.10 ALTER TABLE | `RENAME TO`, `RENAME COLUMN`, `ADD COLUMN`, `DROP COLUMN` |
| M7.11 Date/time | `date`, `time`, `datetime`, `julianday`, `unixepoch`, `strftime` |
| M7.12 More functions | `printf`/`format`, `char`, `unicode`, `zeroblob`, `randomblob`, `like()`, `glob()` |
| M7.13 Pragmas | `table_info`, `index_list`, `index_info`, `page_size` (on create), `user_version`, `application_id`, `freelist_count`, `page_count` |
| M7.14 EXPLAIN QUERY PLAN | Textual plan output based on the M4.10 plan dump |
| M7.15 Foreign keys (optional) | `PRAGMA foreign_keys`, `ON DELETE/UPDATE` actions |
| M7.16 sqllogictest | Run a selected subset of SQLite's own `sqllogictest` |

**Phase done when:** ≥ 1000 differential queries/statements match sql.js, and the selected
`sqllogictest` subset passes.

### Phase 8: Robustness and performance

| Milestone | Scope | Done when |
|-----------|-------|-----------|
| M8.1 Concurrency | Two sessions on the same file. Writer locking, `SQLITE_BUSY` on conflict, reader cache invalidation through the change counter. | Two-session tests pass |
| M8.2 Corruption handling | Detect and raise `SQLITE_CORRUPT`, never a short dump | Fuzzing page bytes on the fixtures gives no dumps |
| M8.3 integrity_check | Our own `PRAGMA integrity_check` | Results agree with sql.js on good and broken files |
| M8.4 Profiling and optimization | Page cache sizing, avoid `xstring` copies (offset-based readers), batch `MODIFY ... FROM TABLE` on flush, hot paths (record decode, comparisons) | Measurable gains over the M0.7 baseline |
| M8.5 Benchmarks in CI | Rows/sec for insert, point lookup, scan | Tracked for regressions |
| M8.6 Large files | 100 MB database, 1M rows | Runs within agreed time and memory limits |
| M8.7 Memory limits | Streaming result sets, external sort for big `ORDER BY` (spill to a temp file in the memory VFS) | Big sorts run without loading everything into memory |

### Phase 9: Real SAP systems

| Milestone | Scope | Done when |
|-----------|-------|-----------|
| M9.1 Target versions | abaplint config for `v750` (optional `Cloud`) | Lint passes for `v750` |
| M9.2 On-premise | Install with abapGit on a 7.50+ system | ABAP Unit passes on the system |
| M9.3 ABAP Cloud | Released APIs only (check `CL_ABAP_CONV_CODEPAGE`, table access), separate abaplint config | ABAP Unit passes on BTP / Steampunk |
| M9.4 Authorization | Optional `AUTHORITY-CHECK` hook per file name prefix in the VFS | Tested with a fake check |
| M9.5 Housekeeping | Report to list/export/import/delete files in `ZSQLITE_FILES` | Works on a real system |

### Phase 10: Later

- UTF-16 databases, `VACUUM`, `ATTACH`, triggers, window functions, generated columns,
  `STRICT` tables, the JSON functions, a rollback journal file mode (real SQLite semantics in the
  table), and a VDBE if the operator tree becomes a limit

---

## Testing strategy

| Layer | How |
|-------|-----|
| Unit | ABAP Unit next to each class, run on Node through the transpiler (`npm run unit`) |
| Static | abaplint with a strict rule set (`npm run lint`) |
| Fixtures | Node script + sql.js creates `.db` files and expected JSON. `setup.mjs` loads them into `ZSQLITE_FILES`. |
| Differential | The same SQL runs in sql.js and abap-sqlite, and the result rows and value types are compared |
| Compatibility | Files written by ABAP are exported from the transpiler DB and must pass `PRAGMA integrity_check` in sql.js |
| Randomized | Seeded random DML workloads, checked against sql.js after every N operations |
| On-system | M9.2–M9.3: ABAP Unit on a real SAP system through abapGit |

CI runs `npm test` on every push and PR. The fixtures are regenerated deterministically
(seeded), so they can either be committed or regenerated in CI. That choice is made in M2.1.

## Tooling bugs: ANORMALIES.md

Bugs and gaps found in abaplint, the transpiler, `@abaplint/runtime`, `@abaplint/database-sqlite`
or open-abap-core are recorded in `ANORMALIES.md` at the repository root. This applies to every
milestone, not just the Phase 0 spikes. Nothing gets worked around silently.

One entry per issue:

```markdown
## <short title>

- **Component:** abaplint | transpiler | runtime | database-sqlite | open-abap-core
- **Version:** e.g. @abaplint/transpiler-cli 2.14.11
- **Found in:** milestone / file, e.g. M1.2 `src/util/zcl_sqlite_bytes.clas.abap`
- **Status:** open | reported | fixed upstream (version) | workaround in place
- **Upstream:** link to issue / PR, if any

Minimal ABAP reproduction, expected vs. actual behaviour.

**Workaround:** what this repo does instead, and where (search tag `ANORMALY:`), so it can be
removed once fixed upstream.
```

Rules:

- Add the entry when the bug is found, with a minimal reproduction.
- Mark every workaround in the code with a comment `" ANORMALY: <short title>`, so it is
  easy to find and remove when an upstream fix lands.
- Report the issue upstream (abaplint/transpiler, open-abap) when it is clearly a bug. Then
  update **Status** and **Upstream**.
- When bumping tool versions, re-check open entries and remove workarounds that are fixed.
- abaplint false positives that are only silenced through `abaplint.jsonc` or pseudo comments
  are recorded too.

## Risks and open questions

| Risk | Mitigation |
|------|------------|
| Transpiler gaps (RAWSTRING in DB, `FOR UPDATE`, int8 edge cases, bit ops) | Found by the Phase 0 spikes (M0.4–M0.6) and recorded in `ANORMALIES.md`. Fix upstream in transpiler/open-abap, or work around. |
| `xstring` performance in ABAP (copies on every slice) | Offset-based readers over one page buffer. Measure in M0.7 and M8.4. |
| Float64 encoding without native reinterpret casts | Manual IEEE 754 encoding in M1.3, fully tested including edge cases |
| Correct b-tree balancing is subtle | Start with simple splits that are valid but not optimal. Verify every write with `integrity_check` in sql.js. |
| Type affinity and comparison semantics are intricate | Differential testing against sql.js from M4.5 on |
| LUW semantics differ from SQLite journaling (D3) | Documented. The library never calls `COMMIT WORK` unless asked. |
| Row size limits for `RAWSTRING` on some DBs at 64 KiB pages | Block size can be smaller than the page size if needed (a page then spans several rows). Decided in M0.4. |
