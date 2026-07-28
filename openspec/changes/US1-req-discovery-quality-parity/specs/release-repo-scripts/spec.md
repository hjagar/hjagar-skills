# Capability Spec: Release Repo Scripts

## Overview
Updates `cli/Release-Repo.sh` and `cli/Release-Repo.ps1` to integrate the shared skill quality gate, ensuring all declared skills are validated and versions verified prior to release packaging.

## Requirements

### Requirement: Quality Gate Integration
The release scripts (`cli/Release-Repo.sh` and `cli/Release-Repo.ps1`) MUST invoke the shared skill quality gate to validate all participating skills as part of the pre-release process.

### Requirement: Skill Version Verification
Release scripts MUST verify that metadata version declarations across skills match release targets, including validating `req-discovery` version `1.1.0`.

### Requirement: Immediate Release Abort on Error
If any skill validation check or version verification fails, the release scripts MUST immediately abort execution with a non-zero exit status and MUST NOT generate release distribution artifacts.

## Scenarios

### Scenario: Successful pre-release verification across participating skills
- Given all participating skills pass shared quality gate validation and version checks
- When `Release-Repo.sh` or `Release-Repo.ps1` is executed
- Then the script MUST complete all validation steps successfully and package the release distribution

### Scenario: Abort release on quality gate failure
- Given a participating skill fails contract validation during the shared quality gate step
- When `Release-Repo.sh` or `Release-Repo.ps1` is executed
- Then the script MUST display the validation failure, abort execution immediately with a non-zero status, and omit release packaging
