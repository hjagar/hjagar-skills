## US40: `/commit-push` — safe conventional commit + push for any pending changes

**As a** Claude Code user working across multiple repos
**I want** a `/commit-push` skill that stages, commits (conventional format), and pushes pending working-tree changes, reusing memsync's safety guardrails
**So that** I can say "commit and push" and get it done safely and correctly formatted without doing every step by hand

### Acceptance criteria

**Scenario 1: Clean pending changes on a non-protected branch**
- Given the working tree has pending changes and the current branch is not protected
- When the user invokes the skill
- Then it stages the changes, generates a conventional-commit message from the diff (or uses one the user supplied), commits, and pushes to the tracked remote branch

**Scenario 2: Current branch is protected**
- Given the current branch matches the repo's protected-branch pattern (e.g. `main`)
- When the user invokes the skill
- Then it refuses to commit directly and tells the user to create a feature branch first, performing no git write

**Scenario 3: Mixed pending changes across unrelated concerns**
- Given the working tree has changes that look unrelated to each other (detected heuristically, e.g. by directory/file-type clustering)
- When the user invokes the skill
- Then it asks the user whether to bundle everything into one commit or split, before staging anything

**Scenario 4: Nothing pending**
- Given the working tree has no pending changes
- When the user invokes the skill
- Then it reports there is nothing to commit and performs no further action

**Scenario 5: No commit type/scope clearly inferable from the diff**
- Given the diff doesn't clearly map to a single conventional-commit type/scope (low confidence)
- When the skill drafts the commit message
- Then it proposes its best-guess message and asks the user to confirm or edit before committing; a high-confidence message commits without asking

### Dependencies
- None identified (reuses the guardrail pattern from `/memsync`, US38, but isn't blocked by it)

<!-- [AI-DATA]
id: US40
type: feat
breaking: false
dependencies: []
metadata:
  scope:
    backend: false
    frontend: false
  role: "Claude Code user"
  endpoint: "none"
  auth: "none"
  ui: "none"
scenarios:
  - name: "Clean pending changes on a non-protected branch"
    given: "the working tree has pending changes and the current branch is not protected"
    when: "the user invokes the skill"
    then: "it stages the changes, generates a conventional-commit message from the diff (or uses one the user supplied), commits, and pushes to the tracked remote branch"
  - name: "Current branch is protected"
    given: "the current branch matches the repo's protected-branch pattern (e.g. main)"
    when: "the user invokes the skill"
    then: "it refuses to commit directly and tells the user to create a feature branch first, performing no git write"
  - name: "Mixed pending changes across unrelated concerns"
    given: "the working tree has changes that look unrelated to each other (detected heuristically, e.g. by directory/file-type clustering)"
    when: "the user invokes the skill"
    then: "it asks the user whether to bundle everything into one commit or split, before staging anything"
  - name: "Nothing pending"
    given: "the working tree has no pending changes"
    when: "the user invokes the skill"
    then: "it reports there is nothing to commit and performs no further action"
  - name: "No commit type/scope clearly inferable from the diff"
    given: "the diff doesn't clearly map to a single conventional-commit type/scope (low confidence)"
    when: "the skill drafts the commit message"
    then: "it proposes its best-guess message and asks the user to confirm or edit before committing; a high-confidence message commits without asking"
-->
