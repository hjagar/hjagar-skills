# Memsync Flow — Implementation Detail

Detailed command sequence backing `SKILL.md`'s Execution Steps. `engram` here is the standalone `engram` CLI (`engram sync`, not the `gentle-ai` CLI, which has no memory subcommand).

## 1. Branch Protection Check

```bash
branch=$(git branch --show-current)
```

- If `branch` is empty (detached HEAD), treat it as protected — refuse and ask the user to create a branch.
- If `gh` is available and the repo has a GitHub remote, check real protection:
  ```bash
  gh api "repos/{owner}/{repo}/branches/${branch}/protection" \
    && echo "protected" || echo "unprotected (404 = no protection configured)"
  ```
  Resolve `{owner}/{repo}` from `gh repo view --json nameWithOwner -q .nameWithOwner`.
- If `gh` is unavailable, there is no GitHub remote, or the API call errors for a reason other than a clean 404, fall back to a name heuristic: treat `main` and `master` as protected, everything else as not.
- On protected → stop immediately per Hard Rule 1. Do not run `engram sync` first — checking the branch is step 2, before any sync side effect.

## 2. Detecting a New Chunk

`engram sync` (no flags) exports any new local memories as a compressed chunk into `.engram/chunks/` and updates `.engram/manifest.json`. It is idempotent — running it with nothing new to export does not create files or fail, it just does nothing observable on disk.

Detect whether it did anything two ways, and prefer the first:

1. **Status delta** — capture `engram sync --status` before, run `engram sync`, capture `engram sync --status` after. Compare "Local chunks" count. Unchanged → no new chunk.
2. **Git delta (fallback / confirmation)** — `git status --porcelain -- .engram/` before and after `engram sync`. Empty after → no new chunk. Non-empty → the new/modified paths under `.engram/chunks/` plus `.engram/manifest.json` are exactly the file set to stage in step 4.

If both signal "no new chunk", stop per Hard Rule 4 and report the current sync status to the user (local vs. remote chunk counts) so they know nothing was lost — it's already in sync.

## 3. Working-Tree Check

```bash
git status --porcelain | grep -v '^.. \.engram/'
```

- Empty output → nothing else pending, go straight to commit with just the Engram file set.
- Non-empty output → list the files to the user and ask (per Hard Rule 3): include them in this same commit, or sync memory only and leave the rest untouched. Never assume either answer.

## 4. Commit & Push

Stage exactly the resolved set (Engram files, plus any user-approved extras):

```bash
git add .engram/manifest.json .engram/chunks/<new-or-changed-file>
# + any user-approved extra paths, added explicitly by path — never `git add -A`/`git add .`
git commit -m "chore(memory): sync session memory"
git push origin "$branch"
```

- Commit message follows this repo's conventional-commit convention; adjust the `chore(memory): ...` subject if the user wants a more specific one (e.g. naming the branch/topic), but keep the `chore(memory):` type/scope.
- No AI attribution trailer (`Co-Authored-By`, etc.) unless the project's own conventions require one.
- After push succeeds, report the branch, the commit SHA (`git rev-parse --short HEAD`), and the chunk file(s) pushed as the `Stored at:` line.
