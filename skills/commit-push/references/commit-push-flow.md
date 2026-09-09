# Commit-Push Flow — Implementation Detail

Detailed command sequence backing `SKILL.md`'s Execution Steps.

## 1. Branch Protection Check

Identical to `/memsync`'s check (`skills/memsync/references/memsync-flow.md` §1):

```bash
branch=$(git branch --show-current)
```

- Empty `branch` (detached HEAD) → treat as protected, refuse, ask the user to create a branch.
- If `gh` is available and the repo has a GitHub remote, check real protection:
  ```bash
  gh api "repos/{owner}/{repo}/branches/${branch}/protection" \
    && echo "protected" || echo "unprotected (404 = no protection configured)"
  ```
  Resolve `{owner}/{repo}` from `gh repo view --json nameWithOwner -q .nameWithOwner`.
- If `gh` is unavailable, there is no GitHub remote, or the API call errors for a reason other than a clean 404, fall back to the name heuristic: treat `main`/`master` as protected, everything else as not.
- On protected → stop immediately per Hard Rule 1, before running anything else.

## 2. Working-Tree Listing

```bash
git status --porcelain
```

Empty output → stop per Hard Rule 5 (nothing pending). Otherwise parse each line's path (strip the two-character status prefix) into the pending-paths list used by cluster analysis.

## 3. Cluster Detection

Group each pending path into a cluster key:

1. If the path starts with `skills/<name>/`, the cluster key is `skills/<name>`.
2. Else if the path starts with `openspec/changes/<change-id>/`, the cluster key is `openspec/<change-id>`.
3. Else the cluster key is the path's first directory segment (e.g. `cli`, `docs`, `.github`), or the bare filename if the path has no directory component (root-level files).

Distinct cluster keys across the pending-paths list are the clusters.

- **1 cluster** → proceed straight to drafting its commit message (step 4), no question asked.
- **2+ clusters** → ask the user explicitly: bundle everything into one commit, or split into one commit per cluster (in cluster order). Never assume either answer. The answer resolves the ordered list of staging sets used by step 4 — one set (all paths) if bundled, one set per cluster if split.

## 4. Commit Message Inference & Confidence

For each staging set, inspect its paths and diff content (`git diff -- <paths>` / untracked file contents) to infer `type(scope): description` using this repo's conventional-commit types (`build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test`, matching `cli/Release-Repo.sh`'s and the branch-pr skill's type table).

**High-confidence signals** (commit without asking, per Hard Rule 4):
- Every path in the set is new (untracked) and lives entirely under one `skills/<name>/` cluster → `feat(<name>): add <short description>`.
- Every path in the set is under `docs/` or is a `*.md` file outside `skills/` → `docs(<scope>): <short description>`.
- Every path in the set is a test file/fixture → `test(<scope>): <short description>`.
- Every path in the set is under `.github/workflows/` → `ci(<scope>): <short description>`.
- Every path in the set is under `.github/` but not `workflows/` (e.g. `ISSUE_TEMPLATE/`, `PULL_REQUEST_TEMPLATE.md`) → `chore(github): <short description>`.
- The diff is a pure deletion/removal with no behavior addition → `chore(<scope>): remove <short description>` or `refactor(<scope>): ...` if it's a restructuring rather than a removal — pick based on whether the removed content's behavior still exists elsewhere.

**Low-confidence** (anything not matching a signal above, or a set mixing add/modify/delete across ambiguous intent — e.g. a source change that could be `fix` or `refactor`): propose the best-guess `type(scope): description` and ask the user to confirm or edit before committing. Never commit a low-confidence message unconfirmed.

## 5. Stage, Commit, Push

For each resolved staging set, in order:

```bash
git add <exact paths in this set>   # never git add -A / git add .
git commit -m "<type>(<scope>): <description>"
```

No AI attribution trailer (`Co-Authored-By`, etc.) unless the project's own conventions require one.

After every staging set in the list has been committed:

```bash
git push -u origin "$branch"   # -u only needed on first push of a new branch
```

Report the branch, each commit's short SHA (`git rev-parse --short HEAD` after each), and the files staged in it as the `Stored at:` line.
