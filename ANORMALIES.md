# ANORMALIES: tooling bugs and workarounds

Bugs and gaps found in abaplint, the transpiler, `@abaplint/runtime`,
`@abaplint/database-sqlite` or open-abap-core while building abap-sqlite. This applies to
every milestone, not just the Phase 0 spikes. Nothing gets worked around silently.

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

## Open entries

## SELECT ... FOR UPDATE is silently dropped by the transpiler

- **Component:** transpiler
- **Version:** @abaplint/transpiler-cli 2.14.13
- **Found in:** M0.5 `src/vfs/zcl_sqlite_files.clas.testclasses.abap`
- **Status:** open
- **Upstream:** none yet

```abap
DATA ls_file TYPE zsqlite_files.
SELECT SINGLE FOR UPDATE mandt, filename, blockno, data
  FROM zsqlite_files
  INTO @ls_file
  WHERE mandt = @sy-mandt AND filename = @c_file AND blockno = 0.
```

Expected: the selected row is locked until `COMMIT WORK` / `ROLLBACK WORK`, or the statement fails
where the backend cannot lock. Actual: the statement succeeds and the generated JavaScript has no
`FOR UPDATE` clause at all:

```js
await abap.statements.select(ls_file, {select: "SELECT \"mandt\", ... FROM "
  + abap.buildDbTableName("zsqlite_files") + " WHERE ... UP TO 1 ROWS", primaryKey: [...]});
```

SQLite has no `FOR UPDATE`, so the clause cannot be honoured. Because the transpiler drops it
silently, locking bugs are invisible in the transpiler.

**Workaround:** the transpiler tests only document that the syntax is accepted
(`src/vfs/zcl_sqlite_files.clas.testclasses.abap`, search tag `ANORMALY:`). Locking is verified on a
real SAP system only (D5, M9.2).

## int8 arithmetic does not raise CX_SY_ARITHMETIC_OVERFLOW

- **Component:** runtime
- **Version:** @abaplint/runtime 2.14.13
- **Found in:** M0.6 `src/util/zcl_sqlite_language_spike.clas.testclasses.abap`
- **Status:** reported
- **Upstream:** https://github.com/abaplint/transpiler/issues/2042

```abap
DATA lv_max TYPE int8.
DATA lv_one TYPE int8 VALUE 1.
DATA lv_result TYPE int8.

lv_max = 9223372036854775807.
lv_result = lv_max + lv_one.
```

Expected: `CX_SY_ARITHMETIC_OVERFLOW`, like ABAP. Actual: the arithmetic operators use unbounded
BigInt values without a range check, so `lv_result` becomes `9223372036854775808`. The same
happens at the lower boundary (`-2^63 - 1`).

**Workaround:** none in the spike test, it accepts both behaviours. Engine code must check values
that can leave the int8 range before doing arithmetic on them (M1.1 i64 decode, M2.5/M5.4 record
sizes).

## int8 to xstring assignment crashes

- **Component:** runtime
- **Version:** @abaplint/runtime 2.14.13
- **Found in:** M0.6 `src/util/zcl_sqlite_language_spike.clas.testclasses.abap`
- **Status:** open
- **Upstream:** https://github.com/abaplint/transpiler/issues/1963

```abap
DATA lv_value TYPE int8.
DATA lv_data TYPE xstring.

lv_value = 255.
lv_data = lv_value.
```

Expected (ABAP 7.58): minimal big endian bytes for non-negative values, so `'FF'` here. Actual:
`TypeError: value.get is not a function`. `XString.set` handles `number` and `XString`, but not the
BigInt that `Integer8.get()` returns. The upstream issue also covers the different padding of
int8 to `x LENGTH n`.

**Workaround:** assign through a `TYPE x LENGTH 8` field first and then to the xstring
(`int8_to_hex` in the spike test, search tag `ANORMALY:`). That is always eight bytes, which is
what the fixed-width i64 record format needs.

## xstring substring assignment with variable offset/length is rejected

- **Component:** abaplint and transpiler
- **Version:** @abaplint/cli 2.120.90, @abaplint/transpiler-cli 2.14.13
- **Found in:** M1.1 `src/util/zcl_sqlite_bytes.clas.abap`
- **Status:** open, deliberate limitation in the toolchain
- **Upstream:** none

```abap
DATA lv_data TYPE xstring.
DATA lv_offset TYPE i VALUE 2.
DATA lv_length TYPE i VALUE 2.
DATA lv_hex TYPE xstring.

lv_hex = 'AABB'.
lv_data+lv_offset(lv_length) = lv_hex.
```

Expected: valid ABAP, the section is replaced. Actual: abaplint `check_syntax` and the transpiler
both report `xstring/string offset/length in writer position not possible`; the syntax check
explicitly rejects xstrings and strings in writer position.

**Workaround:** concatenate the part before the section, the replacement and the part after
(`write_bytes` in `zcl_sqlite_bytes`, search tag `ANORMALY:`). Reading with a variable offset and
length works.

## Mixed int8 and f arithmetic is calculated as int8

- **Component:** runtime
- **Version:** @abaplint/runtime 2.14.13
- **Found in:** M1.3 `src/util/zcl_sqlite_bytes.clas.abap`
- **Status:** open
- **Upstream:** none

```abap
DATA lv_mantissa TYPE int8.
DATA lv_two_pow_52 TYPE f.
DATA lv_fraction TYPE f.

lv_mantissa = 2251799813685248.
lv_two_pow_52 = '4.503599627370496E+15'.
lv_fraction = lv_mantissa / lv_two_pow_52.
```

Expected (ABAP calculation type rules): `0.5`, because one operand is `f`. Actual: `0`, the
runtime's operators take the integer branch whenever either operand is `Integer8` and convert the
other operand with `BigInt(parse(...))`, so the division is truncated. The same applies to `+`, `-`
and `*`, which return `Integer8` and can overflow.

**Workaround:** convert the `int8` operand to `f` in a separate assignment before calculating
(`f64_to_f` in `zcl_sqlite_bytes`, search tag `ANORMALY:`).

## MODIFY TABLE on a hashed table updates by full row content

- **Component:** runtime, from code generated by the transpiler
- **Version:** @abaplint/transpiler-cli 2.14.13, @abaplint/runtime 2.14.13
- **Found in:** M1.5 `src/vfs/zcl_sqlite_vfs_memory.clas.abap`
- **Status:** open
- **Upstream:** none yet

```abap
TYPES: BEGIN OF ty_row,
         name TYPE string,
         size TYPE i,
       END OF ty_row.
TYPES ty_rows TYPE HASHED TABLE OF ty_row WITH UNIQUE KEY name.
DATA mt_rows TYPE ty_rows.
DATA ls_row TYPE ty_row.

ls_row-name = 'a'.
INSERT ls_row INTO TABLE mt_rows.
ls_row-size = 1.
MODIFY TABLE mt_rows FROM ls_row.
```

Expected: the row with key `name = 'a'` is updated to `size = 1`. Actual: the transpiler emits
`modifyInternal(this.#mt_rows, {from: ls_row})`, and the runtime locates the row with
`readTable(table, {from: options.from})`. That compares the complete work area, so it does not
find the row after `size` changed and tries to insert a second row with the same key; the hashed
table rejects it with `sy-subrc = 4`, so the update is lost. The table key is not passed to
`modifyInternal`.

**Workaround:** delete the row by its key and insert the updated work area (`put_file` and
`put_block` in `zcl_sqlite_vfs_memory`, `put_cache` in `zcl_sqlite_pager`, search tag
`ANORMALY:`).

## xstring substring is rejected in method argument positions

- **Component:** abaplint and transpiler
- **Version:** @abaplint/cli 2.120.90, @abaplint/transpiler-cli 2.14.13
- **Found in:** M1.5 `src/vfs/zcl_sqlite_vfs_memory.clas.abap`
- **Status:** open
- **Upstream:** none yet

```abap
DATA lv_data TYPE xstring VALUE 'AABBCCDD'.
DATA lv_offset TYPE i VALUE 2.
DATA lv_length TYPE i VALUE 2.
DATA lv_part TYPE xstring.

lv_part = lv_data+lv_offset(lv_length).                 " accepted
some_method( iv_data = lv_data+lv_offset(lv_length) ).  " rejected
```

Expected: the substring is a valid actual parameter. Actual: abaplint `check_syntax` reports
`Offsets or lengths cannot be specified for fields of type "STRING" or "XSTRING" in the current
statement`, and the transpiler does not parse the call. This is separate from the writer-position
entry above: assigning the same substring to a local variable works.

**Workaround:** copy the substring to a local variable and pass that (`write_file` in
`zcl_sqlite_vfs_memory` and `check_large` in `zcl_sqlite_vfs_contract`, search tag `ANORMALY:`).

## sql.js export resets the schema version

- **Component:** database-sqlite / sql.js
- **Version:** sql.js 1.15.2
- **Found in:** M2.2 `test/tools/make-fixtures.mjs`
- **Status:** open
- **Upstream:** none yet

```js
import initSqlJs from "sql.js";

const SQL = await initSqlJs();
const db = new SQL.Database();
db.run("CREATE TABLE scratch (value)");
db.run("DROP TABLE scratch");
db.run("VACUUM");
console.log(db.exec("PRAGMA schema_version")[0].values[0][0]); // 3
const bytes = db.export();
console.log(Buffer.from(bytes).readUInt32BE(40));              // 1
```

Expected: the schema cookie in the exported header is the value `PRAGMA schema_version` reports
before the export. Actual: sql.js reports 3 in the live database, but writes 1 to the file. Native
SQLite writes 3, and reopening the exported sql.js file also reports 1.

**Workaround:** write the fixture, reopen the exported bytes in a new `SQL.Database`, and derive
the expected contents from that copy (`writeFixture` in `test/tools/make-fixtures.mjs`, search tag
`ANORMALY:`).

## Integer to string conversion leaves a trailing blank

- **Component:** runtime
- **Version:** @abaplint/runtime 2.14.13
- **Found in:** M2.6 `src/btree/zcl_sqlite_cursor.clas.testclasses.abap`
- **Status:** open
- **Upstream:** none yet

```abap
DATA lv_text TYPE string.

lv_text = 1.
```

Expected: `lv_text` is `'1'`, length 1, like on a real SAP system. Actual: `lv_text` is `'1 '`,
length 2. The trailing blank makes padding and string comparisons wrong.

**Workaround:** call `CONDENSE` after the assignment before padding or comparing
(`expected_value` in the cursor tests, search tag `ANORMALY:`).

## Nested inline table constructors are rejected by the parser

- **Component:** abaplint
- **Version:** @abaplint/cli 2.120.90, @abaplint/transpiler-cli 2.14.13
- **Found in:** M2.10 `src/schema/zcl_sqlite_catalog.clas.testclasses.abap`
- **Status:** open
- **Upstream:** none yet

```abap
TYPES: BEGIN OF ty_inner,
         value TYPE i,
       END OF ty_inner.
TYPES: BEGIN OF ty_row,
         c1 TYPE ty_inner,
       END OF ty_row.
TYPES ty_rows TYPE STANDARD TABLE OF ty_row WITH DEFAULT KEY.
DATA lt_rows TYPE ty_rows.

lt_rows = VALUE #( ( c1 = VALUE #( value = 1 ) ) ).
```

Expected: the table constructor is accepted. Actual: abaplint's parser reports a syntax error
at the assignment (`Statement does not exist ... "lt_rows"`), and the generated code is not
produced. The same happens when the inner values come from method calls.

**Workaround:** build one work area with a single-row `VALUE #( ... )` and `APPEND` it, instead of
nesting a table constructor (`ltcl_fixture_breadth` in the catalog tests, search tag `ANORMALY:`).

## Numeric and hex literals are rejected as method arguments

- **Component:** abaplint
- **Version:** @abaplint/cli 2.120.90, @abaplint/transpiler-cli 2.14.13
- **Found in:** M2.10 `src/schema/zcl_sqlite_catalog.clas.testclasses.abap`
- **Status:** open
- **Upstream:** none yet

```abap
some_method( 1.5 ).
some_method( x'01' ).
```

Expected: decimal and hexadecimal literals are valid actual parameters. Actual: abaplint's parser
stops at the decimal point (`"5"` is reported as the unexpected token) or at the whole statement
for the hex literal.

**Workaround:** pass quoted character literals and let the formal parameter convert them
(`real_value( '1.5' )`, `blob_value( '01' )` in the catalog tests, search tag `ANORMALY:`).

## String and character literal comparison trims blanks

- **Component:** @abaplint/runtime
- **Version:** @abaplint/runtime 2.14.13, open-abap-core f735eed652288c8ed85b3083a187cc3e7e4a9b97
- **Found in:** M3.1 `src/sql/zcl_sqlite_tokenizer.clas.abap`
- **Status:** open
- **Upstream:** none yet

```abap
DATA lv_char TYPE string.
lv_char = | |.
IF lv_char = ' '.
  " not reached in the transpiler
ENDIF.
```

Expected: a string containing one space equals the character literal `' '`. Actual: `eq` compares
the string with `getTrimEnd()` of the character operand, so the right side becomes empty and the
comparison is false.

**Workaround:** compare with a string literal (`| |` or a backtick literal). Search tag
`ANORMALY:` in `zcl_sqlite_tokenizer`.

## Closed entries

None yet.
