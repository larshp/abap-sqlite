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

None yet.

## Closed entries

None yet.
