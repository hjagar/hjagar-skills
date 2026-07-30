## uninstall scripts multi-skill parameterization

**As a** hjagar-skills maintainer
**I want** `cli/uninstall.sh` and `cli/uninstall.ps1` to replace `us-refinement-uninstall.*` and accept `--skill <name>` or `--all` flags
**So that** any individual skill or all installed skills can be cleanly uninstalled from AI agent directories and central storage

### Acceptance criteria

**Scenario 1: Uninstalling a single named skill**
- Given an installed skill (e.g. `us-refinement` or `req-discovery`)
- When `uninstall.sh --skill <name>` (or `uninstall.ps1 -Skill <name>`) is executed
- Then it removes that skill's payload from all agent directories (`~/.gemini/skills/<name>`, `~/.claude/skills/<name>`, `~/.cursor/skills/<name>`, etc.), removes Kiro steering file `~/.kiro/steering/<name>.md`, and cleans central storage `~/.hjagar/skills/<name>`

**Scenario 2: Uninstalling all skills**
- Given installed skills across agent directories
- When `uninstall.sh --all` (or `uninstall.ps1 -All`) is executed
- Then it uninstalls all skills under `skills/*/` from all agent directories, removes all Kiro steering files, and cleans central storage `~/.hjagar/skills`

**Scenario 3: Legacy script replacement**
- Given legacy `cli/us-refinement-uninstall.sh` and `cli/us-refinement-uninstall.ps1`
- When `uninstall.sh` and `uninstall.ps1` are created
- Then the legacy `us-refinement-uninstall.*` files are deleted from `cli/`

### Dependencies
- Follows parameterization pattern established in US4 (`install`/`update`) and US5 (`Release-Repo`)

### Resolved decisions
- [x] Interface parity with `install`/`update`: `--skill <name>` (Bash) / `-Skill <name>` (PowerShell) and `--all` / `-All` flags.
- [x] Legacy single-skill `us-refinement-uninstall.*` files in `cli/` are replaced by unified `cli/uninstall.sh` and `cli/uninstall.ps1`.

<!-- [AI-DATA]
id: US7
type: refactor
breaking: true
dependencies: [US4]
metadata:
  scope:
    backend: true
    frontend: false
  role: "hjagar-skills maintainer"
  endpoint: "none"
  auth: "none"
  ui: "none"
scenarios:
  - name: "Uninstalling a single named skill"
    given: "An installed skill (e.g. us-refinement or req-discovery)"
    when: "uninstall.sh --skill <name> / uninstall.ps1 -Skill <name> is run"
    then: "It removes that skill from all agent directories, Kiro steering, and central storage"
  - name: "Uninstalling all skills"
    given: "Installed skills across agent directories"
    when: "uninstall.sh --all / uninstall.ps1 -All is run"
    then: "It uninstalls all skills from agent directories and removes central storage"
  - name: "Legacy script replacement"
    given: "Legacy us-refinement-uninstall.* files"
    when: "uninstall.sh and uninstall.ps1 are created"
    then: "Legacy files are removed from cli/"
-->
