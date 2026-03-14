# Renovate Runbook

This runbook covers the initial setup of the Renovate GitHub App for automated dependency updates, and how to verify and manage its operation.

---

## Overview

Renovate monitors GitHub Actions workflow files and OpenTofu providers for version updates, and automatically opens PRs to `develop` when updates are available.

**Docker image updates are handled separately** by the TryGhost Compose Sync workflow (`.github/workflows/sync-tryghost-compose.yml`), which syncs directly from [TryGhost/ghost-docker](https://github.com/TryGhost/ghost-docker) `main`. See [Updating Ghost Docker Images](../../CLAUDE.md#updating-ghost-docker-images) for details.

`ghost:6-alpine` is intentionally excluded from all automated tracking — it is unpinned by design.

Configuration lives in `renovate.json` at the repository root.

---

## Initial Setup: Install the Renovate GitHub App

This is a one-time manual step required before Renovate will process the repository.

### Step 1: Install the App

1. Navigate to [github.com/apps/renovate](https://github.com/apps/renovate)
2. Click **Configure**
3. Under **Install**, select the **noahwhite** account
4. When prompted to choose a mode, select **Scan and Alert** — this enables automated PR creation; "Scan Only" will not create PRs
5. Under **Repository access**, select **Only select repositories**
6. Choose `ghost-stack` from the list
7. Click **Install**

### Step 2: Verify Renovate Scans the Repository

After installation, Renovate will schedule an initial scan. It will either:

- Open an **onboarding PR** (if it's the first time Renovate has run on the repo) — review and merge it to allow Renovate to proceed
- Begin scanning immediately if a `renovate.json` is already present (which it is)

Check the [Renovate dashboard](https://app.renovatebot.com/dashboard) for scan status, or watch for a new PR in the repository.

---

## How Updates Work

When a new GitHub Actions action version or OpenTofu provider version is released:

1. Renovate detects the version bump on its next scheduled scan
2. Renovate opens a PR to `develop` with branch name `feature/renovate-<package>`
3. The standard CI/CD pipeline runs
4. Review and merge

---

## Troubleshooting

### Renovate is not creating PRs

**Check the dependency dashboard issue** in the repository — Renovate creates a tracking issue that shows pending updates and any errors.

**Check the Renovate app logs** at [app.renovatebot.com/dashboard](https://app.renovatebot.com/dashboard).

**Verify the app is still installed:**
1. Navigate to **github.com/settings/installations** (or the org settings)
2. Confirm the Renovate app shows `ghost-stack` in its repository list

### PR branch name does not follow `feature/` convention

The `branchPrefix` in `renovate.json` is set to `feature/renovate-`. If PRs are appearing with a different prefix, check that `renovate.json` has not been overridden by a global Renovate config at the organisation level.

---

## Related Documentation

- [Updating Ghost Docker Images](../../CLAUDE.md#updating-ghost-docker-images) — automated sync from TryGhost/ghost-docker
- [Renovate documentation](https://docs.renovatebot.com)
