## CI sync workflows to per-skill mirror repos

**As a** hjagar-skills maintainer
**I want** GitHub Actions workflows (one per skill, per the proposal's Phase 4) that `git subtree push` each `skills/<name>/` folder to its own existing mirror repo on push to main
**So that** external consumers cloning e.g. hjagar/us-refinement keep receiving updates made in this monorepo without any manual step

### Acceptance criteria

**Scenario 1: Push to main syncs a changed skill**
- Given a commit on main that only changes files under skills/us-refinement/
- When the corresponding sync workflow runs
- Then it `git subtree push`es those changes to the hjagar/us-refinement mirror repo, preserving history of that subtree

**Scenario 2: Unrelated skill is untouched**
- Given the same commit
- When the other skills' sync workflows evaluate
- Then skills with no changed files are not pushed/triggered unnecessarily

### Dependencies
- US4, US5 — sequenced strictly after Phase 3 (install/release parameterization) per the sdd-explore recommendation, since building workflows against still-single-skill-shaped cli/ would just relocate the hardcoding

### Resolved decisions
- [x] Sync mechanism: `git subtree push`, one workflow per skill folder — no third-party sync Action dependency.
- [x] Mirror repos (`hjagar/req-discovery`, `hjagar/res-onboarding`, `hjagar/tc-generator`, `hjagar/us-refinement`) already exist on GitHub — no repo-creation step needed, workflows only need to target them.

<!-- [AI-DATA]
id: US6
type: feat
breaking: false
dependencies: [US4, US5]
metadata:
  scope:
    backend: true
    frontend: false
  role: "hjagar-skills maintainer"
  endpoint: "none"
  auth: "none"
  ui: "none"
scenarios:
  - name: "Push to main syncs a changed skill"
    given: "A commit on main that only changes files under skills/us-refinement/"
    when: "The corresponding sync workflow runs"
    then: "It git subtree pushes those changes to the hjagar/us-refinement mirror repo"
  - name: "Unrelated skill is untouched"
    given: "The same commit"
    when: "Other skills' sync workflows evaluate"
    then: "Skills with no changed files are not pushed/triggered unnecessarily"
-->
