---
name: commit-push
description: "Trigger: /commit-push, commit and push, commitea y subi, guarda y subi los cambios. Stages, commits (conventional format), and pushes any pending working-tree changes, reusing memsync's safety guardrails for any repo."
license: MIT
metadata:
  author: hjagar
  version: "0.1.0"
---

## Activation Contract

Activate this skill when:
- The user types `/commit-push`.
- The user says "commit and push", "commitea y subí los cambios", "guardá y subí esto", or an equivalent request to commit and push pending changes without naming a specific `/memsync`-style memory sync.

## Hard Rules

1. **Protected-Branch Guard:** Never commit or push while the current branch is protected (`main`, `master`, or anything GitHub reports as protected). Stop and tell the user to create a new branch first.
2. **Explicit Staging Only:** Stage exactly the resolved file set by path. Never `git add -A` or `git add .`.
3. **Cluster Detection Before Staging:** Group pending changes into clusters per `references/commit-push-flow.md` before staging anything. If 2+ clusters are detected, ask the user whether to bundle everything into one commit or split into one commit per cluster — never decide unilaterally.
4. **Confidence-Gated Commit Message:** Draft a conventional-commit message per cluster from its diff. Commit without asking only when the inferred type/scope is high-confidence (single, unambiguous mapping per `references/commit-push-flow.md`); otherwise propose the best-guess message and ask the user to confirm or edit before committing.
5. **No-Op Is Not an Error:** If the working tree has no pending changes, report that plainly and stop. No commit, no push.
6. **No AI Attribution:** Never add a `Co-Authored-By` or similar AI attribution trailer to the commit message.

## Decision Gates

| Situation | Action |
| --- | --- |
| Current branch is protected | Stop; tell user to create a new branch (Hard Rule 1) |
| Working tree has no pending changes | Stop; report nothing to commit (Hard Rule 5) |
| One cluster of changes | Draft its commit message, apply the confidence gate, then stage/commit |
| 2+ clusters of changes | Ask user: bundle into one commit or split per cluster (Hard Rule 3) |
| Commit message type/scope is high-confidence | Commit without asking |
| Commit message type/scope is low-confidence | Propose best-guess message, ask user to confirm or edit |
| Branch-protection check unavailable (no `gh`/no remote) | Fall back to name heuristic: treat `main`/`master` as protected |

## Execution Steps

1. **Resolve & Check Branch:** Detect the current branch and its protection status per `references/commit-push-flow.md`. Protected → stop (Hard Rule 1).
2. **Check Working Tree:** List pending changes (`git status --porcelain`). Empty → stop (Hard Rule 5).
3. **Cluster Analysis:** Group the pending paths into clusters per `references/commit-push-flow.md`. 2+ clusters → ask the user to bundle or split (Hard Rule 3); resolve one ordered list of staging sets (one set if bundled or single-cluster, one set per cluster if split).
4. **Draft & Commit Each Set:** For each staging set, infer a conventional-commit type/scope/description from its diff and rate confidence per `references/commit-push-flow.md`. High confidence → commit directly. Low confidence → propose the message and ask the user to confirm or edit (Hard Rule 4). Stage exactly that set's paths, then commit.
5. **Push:** Push the current branch to its tracked remote (or set upstream on first push) after all commits from step 4 are made.

## Output Contract

Return:
- Result: performed / skipped (nothing pending) / blocked (protected branch).
- If performed: the cluster/split decision made, each commit's exact staged files, message, and hash.
- If message confidence was low for any commit: what was proposed and the user's final call.
- A closing `Stored at:` line naming the branch and the commit SHA(s) pushed.

## References

- `references/commit-push-flow.md` — branch-protection detection (shared with `/memsync`), cluster-detection heuristic, conventional-commit type inference and confidence rating, and the stage/commit/push command sequence.
