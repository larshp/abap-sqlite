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

## Closed entries

None yet.
