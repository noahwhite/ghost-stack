# Branch Protection Rules: `main`

This document describes the current branch protection rules enforced on the `main` branch of this project.

## Enforcement Status

- Status: Active

## Rules Enforced

| Rule | Description |
|------|-------------|
| **Require a pull request before merging** | Direct pushes to `main` are disallowed. Changes must be made through PRs. |
| **Require approvals** | At least one approving review is required before a PR can be merged. |
| **Require review from Code Owners** | PRs that modify files with designated code owners must be approved by one of them. |
| **Require linear history** | Prevents merge commits and ensures a clean, linear commit history on `main`. |
| **Prevent force pushes** | Force pushing to `main` is blocked. |
| **Prevent branch deletion** | The `main` branch cannot be deleted. |

## Temporarily Disabled

| Rule | Rationale |
|------|-----------|
| **Require status checks to pass before merging** | Not enabled yet because the project does not currently use CI/CD. This will be revisited in Part 4 of the series. |
| **Require deployments to succeed** | Will be enabled when CI/CD pipelines and deployment workflows are introduced. |
| **Restrict who can push to matching branches** | Currently open to all collaborators. May be restricted in later stages. |

## Notes

- These rules are designed to support the MVP/dev-only phase of the project.
- They will evolve as we introduce CI/CD, staging, and production environments.
- Updates will be tracked in this file and in the [git workflow document](git-workflow-mvp.md).