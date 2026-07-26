## install/update scripts multi-skill parameterization

**As a** hjagar-skills maintainer
**I want** `install.sh`/`install.ps1`, `update.sh`/`update.ps1`, and `lib/skill-payload.sh`/`.ps1` to accept an optional target skill name and resolve paths under `skills/<name>/` instead of hardcoding `us-refinement`
**So that** any skill in this monorepo — one at a time, or all of them — can be installed and updated into agent directories

### Acceptance criteria

**Scenario 1: Installing a single named skill**
- Given a skill other than us-refinement (e.g. req-discovery) with a valid SKILL.md
- When `install.sh --skill req-discovery` (or `install.ps1 -Skill req-discovery`) is run
- Then it copies that skill's SKILL.md + scripts/tests/assets/references to all configured agent directories, not us-refinement's

**Scenario 2: Installing without specifying a skill**
- Given no `--skill`/`-Skill` flag is passed
- When install.sh or install.ps1 runs
- Then every skill under `skills/*/` is installed to all configured agent directories

**Scenario 3: Existing local-mode flag preserved**
- Given the existing `-l`/`--local` (bash) local-mode flag
- When install.sh runs in local mode, with or without `--skill`
- Then local-mode behavior (sourcing from the real checkout instead of downloading a release ZIP) is unchanged

### Dependencies
- None identified — independent of US1-3, but should land before US5 (Release-Repo reuses the same skill-root resolution)

### Resolved decisions
- [x] Invocation interface: `--skill <name>` (bash, lowercase per existing `-l`/`--local`/`-p`/`--path` convention) / `-Skill <name>` (PowerShell, PascalCase per existing convention). Optional in both — omitting it means "all skills". Existing `-l`/`--local` flag (and its PowerShell equivalent) is preserved unchanged.
- [x] `.ps1` scripts get identical parameterization for platform parity (mandatory per repo convention: `.sh`/`.ps1` pairs must stay behaviorally identical).

<!-- [AI-DATA]
id: US4
type: refactor
breaking: true
dependencies: []
metadata:
  scope:
    backend: true
    frontend: false
  role: "hjagar-skills maintainer"
  endpoint: "none"
  auth: "none"
  ui: "none"
scenarios:
  - name: "Installing a single named skill"
    given: "A skill other than us-refinement with a valid SKILL.md"
    when: "install.sh --skill <name> / install.ps1 -Skill <name> is run"
    then: "It copies that skill's payload to all configured agent directories"
  - name: "Installing without specifying a skill"
    given: "No --skill/-Skill flag is passed"
    when: "install.sh or install.ps1 runs"
    then: "Every skill under skills/*/ is installed to all configured agent directories"
  - name: "Existing local-mode flag preserved"
    given: "The existing -l/--local local-mode flag"
    when: "install.sh runs in local mode, with or without --skill"
    then: "Local-mode behavior is unchanged"
-->
