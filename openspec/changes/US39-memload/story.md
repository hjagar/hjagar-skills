## US39: `/memload` — import pending Engram memory chunks into the local DB

**As a** Claude Code user working with Engram across multiple projects/branches
**I want** a `/memload` skill that runs `engram sync --import` at the start of a session (or on demand)
**So that** I pull in memory chunks pushed from another branch or machine without doing it manually

### Acceptance criteria

**Scenario 1: New chunks pending import**
- Given `.engram/` in the working tree has chunk(s) not yet present in the local Engram DB
- When the user runs `/memload`
- Then the skill runs `engram sync --import`, and reports what was imported (chunk count and/or observation count) based on the command's own output or `engram sync --status`

**Scenario 2: Nothing pending to import**
- Given `.engram/` has no chunks the local DB doesn't already have
- When the user runs `/memload`
- Then the skill reports explicitly that there is nothing new to import and performs no further action

### Dependencies
- Engram installed and configured with the AI agent in use.
- `.engram/` present in the working tree (populated by `git pull`/checkout and, on the export side, by the `/memsync` skill — US38, issue #40). Not a hard dependency: `/memload` works standalone against whatever `.engram/` state is on disk.

<!-- [AI-DATA]
id: US39
type: feat
breaking: false
dependencies: []
metadata:
  scope:
    backend: false
    frontend: false
  role: "Claude Code + Engram user"
  endpoint: "none"
  auth: "none"
  ui: "none"
scenarios:
  - name: "New chunks pending import"
    given: ".engram/ in the working tree has chunk(s) not yet present in the local Engram DB"
    when: "The user runs /memload"
    then: "The skill runs engram sync --import and reports what was imported (chunk count and/or observation count)"
  - name: "Nothing pending to import"
    given: ".engram/ has no chunks the local DB doesn't already have"
    when: "The user runs /memload"
    then: "The skill reports explicitly that there is nothing new to import and performs no further action"
-->
