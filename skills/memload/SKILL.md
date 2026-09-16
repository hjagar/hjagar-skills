---
name: memload
description: "Trigger: /memload, cargar memoria pendiente, importar chunks de engram, pull memory changes. Imports pending Engram memory chunks from .engram/ into the local DB (engram sync --import) and reports what was imported."
license: MIT
metadata:
  author: hjagar
  version: "0.1.0"
---

## Activation Contract

Activate this skill when:
- The user types `/memload`.
- The user asks to "importar la memoria pendiente", "cargar los chunks de engram", "traer lo que subieron a .engram", or an equivalent request to pull memory changes into the local Engram DB.

## Hard Rules

1. **Read-Only Against Git:** Never stage, commit, or push. This skill performs no git write, so no branch-protection check is needed — unlike `/memsync`, it is safe on any branch including protected ones.
2. **Relay, Don't Interpret Conflicts:** If `engram sync --import` surfaces memory conflicts, relay the command's own output as-is. Do not add conflict-resolution guidance or trigger `mem_judge` on the user's behalf — resolving conflicts is out of this skill's scope (US39, resolved assumption).
3. **No-Op Is Not an Error:** If there is nothing new to import, report that plainly and stop.
4. **Trust the Command's Own Report:** Derive what was imported from `engram sync --import`'s own output; fall back to an `engram sync --status` before/after delta only if the import command's own output doesn't state counts.

## Decision Gates

| Situation | Action |
| --- | --- |
| Chunks pending import | Run `engram sync --import`, report imported chunk/observation counts |
| Nothing pending | Report nothing to import, stop (Hard Rule 3) |
| Import surfaces conflicts | Relay the command's own output as-is, no extra interpretation (Hard Rule 2) |

## Execution Steps

1. **Check Pending State:** Capture `engram sync --status` to see the local vs. pending chunk count before importing, per `references/memload-flow.md`.
2. **Import:** Run `engram sync --import`.
3. **Report:** Compare against step 1's status (or the import command's own reported counts) and report what was imported, or that nothing was pending (Hard Rule 3).

## Output Contract

Return:
- Result: imported / skipped (nothing pending).
- If imported: the chunk count and/or observation count, based on `engram sync --import`'s own output or the `--status` delta.
- If the import surfaced conflicts, the command's own conflict output relayed verbatim (Hard Rule 2).

## References

- `references/memload-flow.md` — exact `engram sync --import` / `--status` command sequence and pending-state detection.
