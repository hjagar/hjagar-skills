# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`hjagar-skills` is a monorepo of Claude/Gemini/OpenCode/Cursor **agent skills** — no application code, no build/test/lint pipeline. Each skill under `skills/<name>/` is a self-contained Markdown+asset bundle consumed by an AI coding agent at runtime, not compiled or executed directly. See `docs/local/proposal-monorepo-and-shared-cli.md` for the architectural rationale (this repo unifies what used to be 4 separate skill repos: `us-refinement`, `req-discovery`, `res-onboarding`, `tc-generator`).

## Repo layout

```
hjagar-skills/
├── cli/                  # shared install/update/release scripts (bash + PowerShell pairs)
│   ├── install.sh/.ps1
│   ├── update.sh/.ps1
│   ├── Release-Repo.sh/.ps1
│   ├── lib/skill-payload.sh/.ps1   # shared functions sourced by install/update
│   └── us-refinement-uninstall.sh/.ps1
├── skills/
│   ├── us-refinement/    # SKILL.md + assets/ + references/ + scripts/ + tests/
│   ├── req-discovery/    # SKILL.md + assets/ + examples/
│   ├── res-onboarding/   # SKILL.md + references/
│   └── tc-generator/     # SKILL.md + references/
├── .atl/skill-registry.md  # auto-generated index of ALL skills on this machine (not just this repo)
└── .github/workflows/    # currently empty — CI sync to per-skill mirror repos is planned, not implemented
```

## Skill anatomy

Every skill is `SKILL.md` (YAML frontmatter: `name`, `description` — the trigger phrase agents match on — plus optional `license`/`metadata.author`/`metadata.version`) with an `## Activation Contract`, `## Hard Rules`, and `## Decision Gates` section, followed by optional `assets/`, `references/`, `scripts/`, `tests/`, `examples/` subfolders. `SKILL.md` stays deliberately light; detailed logic is pushed into `references/*.md` and linked from a `## References` section rather than inlined — follow this pattern when editing or adding skills.

`us-refinement` is the most mature skill (versioned frontmatter, Python validation script, test fixtures) — use it as the template for structure when building out the others.

## Installer scripts (`cli/`) — multi-skill, monorepo-native

The `cli/install.sh`/`update.sh`/`Release-Repo.sh` scripts and `lib/skill-payload.sh` were originally lifted from the old standalone `us-refinement` repo, where `SKILL.md`, `scripts/`, `tests/`, `lib/` lived at the **repo root**. Per the roadmap in `docs/local/proposal-monorepo-and-shared-cli.md`, Phase 3 (a monorepo-aware, multi-skill installer) has since landed (`8a214d0`, `033b58f`):

- `Release-Repo.sh`/`.ps1` resolve `skills/<name>/SKILL.md` from the repo root and take a `--skill <name>` flag (or positional arg / interactive prompt) to pick which skill to release. No root-level `SKILL.md` assumption remains.
- `install.sh -l/--local -p <path>` and `update.sh` are layout-aware: they check `<src>/skills/<name>/SKILL.md` first and only fall back to `<src>/SKILL.md` at the root (kept for compatibility with a single-skill release ZIP layout).
- The *global* install/update path (no `-l`/`-p`, plain `curl | bash`) resolves releases against `hjagar/hjagar-skills` (this monorepo, made public) by filtering `GET /repos/hjagar/hjagar-skills/releases` for tags matching `<skill>-v*` and picking the highest semver — see `resolve_release_tag`/`install_one_skill_global` in `install.sh` and their PowerShell/`update.*` equivalents (change `US17-global-install-release-resolution`). Omitting `--skill` in `install.sh`/`.ps1` discovers and installs every skill that has a published release (via the same tag list, deduped); omitting it in `update.sh`/`.ps1` updates every skill already installed locally. Neither script defaults to `us-refinement` or any single skill anymore. `Release-Repo.sh`/`.ps1` publish releases with a preflight guard confirming the target repo is `hjagar/hjagar-skills` before tagging, and a zip layout (`skills/<name>/**` + `cli/lib/skill-payload.*`) that mirrors the monorepo so `install_skills` finds everything it needs post-extraction.
- The two formerly-public per-skill mirrors (`hjagar/us-refinement`, `hjagar/req-discovery`) are slated for archival now that they no longer serve any function in the install/update path — see `docs/local/mirror-repos-migration-and-cleanup.md` §6 for the runbook (not yet executed as of this writing; gated on a real `<skill>-v*` release existing and being verified downloadable first).

`install.sh`/`update.sh` distribute a skill to per-agent directories: `~/.gemini/skills/`, `~/.claude/skills/`, `~/.config/opencode/skills/`, `~/.copilot/skills/`, `~/.agents/skills/`, `~/.cursor/skills/`, plus every `~/.claude-*/` multi-account dir, and a special-cased flattened steering file at `~/.kiro/steering/<skill>.md` (Kiro has no folder+SKILL.md convention — see `new_kiro_steering_file` in `lib/skill-payload.sh`). Copies are staged into a `.staging` sibling dir and atomically swapped in, so a failed copy never corrupts an existing install.

`.sh` and `.ps1` variants of every `cli/` script must be kept behaviorally identical (macOS/Linux vs Windows parity) — check both when changing installer logic.

## `.atl/skill-registry.md`

Auto-generated by `gentle-ai skill-registry refresh --force` (do not hand-edit) — indexes every skill installed across this machine's agent directories, not just this repo's `skills/`. Used by orchestrator agents to select which skill paths to hand to subagents.
