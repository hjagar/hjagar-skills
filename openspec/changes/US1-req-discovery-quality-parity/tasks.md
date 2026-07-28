<!-- Review Workload Forecast
Files to modify: 3
Files to create: 7
Risk level: low
Estimated review time: 15 minutes
-->

# Implementation Tasks: US1 req-discovery Quality Parity & Shared Quality Gate

## Phase 1: Foundation (Manifests & Schemas)
- [x] 1.1 Create validation manifest `skills/req-discovery/validation.json` specifying script path `scripts/validate_req_discovery.py` and fixture paths (`tests/mock_valid_req_discovery.md`, `tests/mock_invalid_req_discovery.md`).
- [x] 1.2 Create validation manifest `skills/us-refinement/validation.json` mapping existing validator `scripts/validate_refinement.py` and legacy fixtures (`tests/mock_valid_us.md`, `tests/mock_invalid_us.md`).

## Phase 2: req-discovery Validator & Test Fixtures
- [x] 2.1 Implement Python validator script `skills/req-discovery/scripts/validate_req_discovery.py` enforcing output contract rules:
  - Title header `### <title>`
  - User story format `**Story:** As a ..., I want ..., so that ...`
  - Context format `**Context:** ...`
  - Resolution format `**Resolution:** ...`
  - Confidence rating `**Confidence:** explicit|implied`
  - Optional `**Possible match:**` header structure
  - Hidden English summary comment `<!-- en-summary: ... -->` block per candidate
  - Zero-candidate response exact message verification
- [x] 2.2 Create compliant test fixture `skills/req-discovery/tests/mock_valid_req_discovery.md` containing all required section headers and metadata comments.
- [x] 2.3 Create non-compliant test fixture `skills/req-discovery/tests/mock_invalid_req_discovery.md` with intentional contract violations (missing story elements, invalid confidence, absent summary comment).

## Phase 3: us-refinement Manifest & Fixture Integration
- [x] 3.1 Verify `skills/us-refinement/validation.json` integration with `validate_refinement.py`.
- [x] 3.2 Confirm `mock_valid_us.md` passes and `mock_invalid_us.md` fails with 100% pass/fail parity.

## Phase 4: Shared Quality Gate & Release Script Integration
- [x] 4.1 Create shared quality gate discovery modules `cli/lib/quality-gate.sh` and `cli/lib/quality-gate.ps1` to discover all `skills/*/validation.json` manifests.
- [x] 4.2 Implement secure subprocess execution in quality gate modules running validators against valid (exit code 0) and invalid (non-zero exit code) fixtures.
- [x] 4.3 Update release scripts `cli/Release-Repo.sh` and `cli/Release-Repo.ps1` to invoke the shared quality gate and abort immediately on any validation failure.
- [x] 4.4 Add metadata version check to release scripts verifying version declarations across participating skills, including `req-discovery` version `1.1.0`.

## Phase 5: Version Bump & Verification
- [x] 5.1 Update `skills/req-discovery/SKILL.md` YAML frontmatter `metadata.version` to `1.1.0`.
- [x] 5.2 Execute direct Python validator tests against `mock_valid_req_discovery.md` and `mock_invalid_req_discovery.md`.
- [x] 5.3 Run shared quality gate across `us-refinement` and `req-discovery` to confirm complete validation suite pass.
- [x] 5.4 Execute dry-run release scripts (`cli/Release-Repo.sh` and `cli/Release-Repo.ps1`) to verify pre-release quality gate enforcement and clean abort behavior.
