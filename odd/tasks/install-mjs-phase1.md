# install-mjs-phase1

Objective: Phase 1 of issue #56, a Node `install.mjs` alongside the existing shell scripts (which stay untouched).
Branch: feat/install-mjs-phase1 · Delivery: stacked-to-main, 2 slices (assumption) · Test runner: `node --test cli/tests/*.test.mjs` (node:test, no deps)

## Specs

- S1: "Port `install`, `update` and `uninstall` (incl. the `us-refinement` uninstaller) to Node as `install.mjs` subcommands, reusing `cli/agent-targets.json`." (Note: `cli/us-refinement-uninstall.*` no longer exists; `cli/uninstall.sh` is generic and is what gets ported.)
- S2: "Keep current behavior: per-agent directories, `~/.claude-*` dirs, flattened Kiro steering file, `.staging` copy with atomic swap."
- S3: "Add `--dry-run` to `install`, `update` and `uninstall`: print the plan (which agent directories will change) and ask for confirmation before touching anything."
- S4: "Compare output against the `.sh`/`.ps1` versions before moving on."
- Assumption A1: no external dependencies, so zip extraction is done in-process with `node:zlib` (Node has no built-in unzip).
- Assumption A2: global mode still resolves `<skill>-v*` tags and `<skill>.zip` assets (the unified release is Phase 2/3).
- Assumption A3: confirmation prompt is skipped with `--yes` and when stdin is not a TTY only with `--yes` (otherwise abort), so scripts never hang.

## Tasks

- [x] T1 (S1,S2) core lib: agent paths from manifest + `.claude-*` discovery, staged copy/swap, Kiro steering transform, skill-name validation · inline · commit: 4352b06 (RED: module not found; GREEN: 7/7 node:test)
- [x] T2 (S1,S3) `install` local mode + CLI parsing + plan/`--dry-run`/confirm · inline · commit: a967b64 (RED: module not found; GREEN: 14/14 node:test; real --dry-run matches installed paths)
- [x] T3 (S1,S2) zip reader + global install (tag resolve, download) · inline · commit: a1cb509 (RED: module not found; GREEN: 23/23 node:test; real global --dry-run resolves tag)
- [x] T4 (S1,S3) `update` and `uninstall` subcommands with `--dry-run` · inline · commit: aeca2af (RED: 11 failing; GREEN: 34/34 node:test)
- [x] T5 (S4) output/filesystem comparison against `install.sh`/`update.sh`/`uninstall.sh`; independent verifier (Risk item 5: installers) · delegated verifier · commit: ea55fd9 (sh vs mjs: 441 files identical except CRLF Kiro files; verifier S1-S4 PASS; blocker B1 fixed + test, 35/35)

## Log

L1 (2026-10-25): "empezamos con la #56?" (issue #56: replace shell installers with install.mjs and unify repo releases; this feature is its Phase 1.)
L2: Explored cli/install.sh, update.sh, uninstall.sh, lib/skill-payload.sh, agent-targets.json (Node v24.22.1 available). Old scripts: global dir `~/.hjagar/skills`; update only touches agent paths that already exist; uninstall removes agent dirs, kiro file, central dir.

L3: Verifier blocker B1 (flags silently ignored by other subcommands) fixed in ea55fd9. Known difference kept: Kiro steering for CRLF sources (git-bash sed strips CR in install.sh; install.mjs preserves bytes). Advisory: uninstall --all removes the whole ~/.hjagar/skills (same as old script).
