---
name: checkpoint
description: "Trigger: /checkpoint, checkpoint de sesion, guardar memoria y subir la branch. Saves the session summary to Engram, syncs it to .engram/, and commits+pushes only the resulting chunk to the current branch."
license: MIT
metadata:
  author: hjagar
  version: "1.0.0"
---

## Activation Contract

Activate this skill when:
- The user types `/checkpoint`.
- The user asks to "guardar memoria de la sesion y subirla", "sincronizar engram con la branch", or an equivalent checkpoint request.

## Hard Rules

1. **Protected-Branch Guard:** Never commit or push while the current branch is protected (`main`, `master`, or anything GitHub reports as protected). Stop and tell the user to create a new branch first.
2. **Scoped Staging Only:** Stage only the Engram sync output (`.engram/manifest.json` and the new/changed chunk file(s) under `.engram/chunks/`), plus any other files the user explicitly opts to include. Never `git add -A` or `git add .`.
3. **No Silent Bundling:** If the working tree has other pending changes when staging begins, ask the user whether to include them in this commit — never decide unilaterally.
4. **No-Op Is Not an Error:** If `engram sync` produces no new chunk, report that plainly and stop. No commit, no push.
5. **Summary Before Sync:** Always save the session summary to Engram first, so it is captured by the sync.

## Decision Gates

| Situation | Action |
| --- | --- |
| Current branch is protected | Stop; tell user to create a new branch (Hard Rule 1) |
| `engram sync` reports no new/pending chunk | Stop; report nothing to sync (Hard Rule 4) |
| New chunk synced, working tree otherwise clean | Stage chunk + manifest, commit, push |
| New chunk synced, other files also modified/untracked | Ask user: include those files or checkpoint memory only (Hard Rule 3) |
| Branch-protection check unavailable (no `gh`/no remote) | Fall back to name heuristic: treat `main`/`master` as protected |

## Execution Steps

1. **Save Summary:** Call `mem_session_summary` with the session's Goal/Discoveries/Accomplished/Next Steps.
2. **Resolve & Check Branch:** Detect the current branch and its protection status per `references/checkpoint-flow.md`. Protected → stop (Hard Rule 1).
3. **Sync Memory:** Run `engram sync` and detect whether it produced a new/changed chunk per `references/checkpoint-flow.md`. None → stop (Hard Rule 4).
4. **Check Working Tree:** List pending changes outside `.engram/`. Non-empty → ask the user per Hard Rule 3.
5. **Commit & Push:** Stage the resolved file set, commit with the conventional-commit message from `references/checkpoint-flow.md`, and push to the current branch.

## Output Contract

Return:
- Checkpoint result: performed / skipped (no new chunk) / blocked (protected branch).
- If performed: exact files staged, the commit message/hash, and push confirmation.
- If other pending changes were found: the user's decision and how it was applied.
- A closing `Stored at:` line naming the branch, commit SHA, and chunk file(s) pushed.

## References

- `references/checkpoint-flow.md` — exact `engram sync` diffing logic, branch-protection detection (with fallback), and the commit/push command sequence.
