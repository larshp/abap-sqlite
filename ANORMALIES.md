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

## Closed entries

None yet.
