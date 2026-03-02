# Renovate Runbook

This runbook covers the initial setup of the Renovate GitHub App for automated Docker image version updates, and how to verify and manage its operation.

---

## Overview

Renovate monitors `compose.yml.tftpl` for new versions of the three pinned Docker images and automatically opens a PR to `develop` when updates are available:

| Image | Tracking |
|-------|----------|
| `caddy:*-alpine` | Tag + SHA256 digest |
| `mysql:8.0.*` | Tag + SHA256 digest |
| `ghost/traffic-analytics:*` | Tag + SHA256 digest |

`ghost:6-alpine` is intentionally excluded — it is unpinned by design.

Configuration lives in `renovate.json` at the repository root.

---

## Initial Setup: Install the Renovate GitHub App

This is a one-time manual step required before Renovate will process the repository.

### Step 1: Install the App

1. Navigate to [github.com/apps/renovate](https://github.com/apps/renovate)
2. Click **Configure**
3. Under **Install**, select the **noahwhite** account
4. Under **Repository access**, select **Only select repositories**
5. Choose `ghost-stack` from the list
6. Click **Install**

### Step 2: Verify Renovate Scans the Repository

After installation, Renovate will schedule an initial scan. It will either:

- Open an **onboarding PR** (if it's the first time Renovate has run on the repo) — review and merge it to allow Renovate to proceed
- Begin scanning immediately if a `renovate.json` is already present (which it is)

Check the [Renovate dashboard](https://app.renovatebot.com/dashboard) for scan status, or watch for a new PR in the repository.

### Step 3: Confirm the `.tftpl` File Is Detected

After the first scan, verify Renovate found the compose file:

1. Navigate to the repository on GitHub
2. Look for a Renovate dependency dashboard issue (Renovate creates one automatically)
3. Confirm `compose.yml.tftpl` appears under detected files

If the file is not detected, check the `fileMatch` pattern in `renovate.json`:

```json
"docker-compose": {
  "fileMatch": ["(^|/)compose\\.yml\\.tftpl$"]
}
```

---

## How Updates Work

When a new image version is released upstream:

1. Renovate detects the version bump on its next scheduled scan
2. Renovate opens a PR to `develop` with branch name `feature/renovate-ghost-stack-docker-images`
3. The PR updates the image tag and SHA256 digest in `compose.yml.tftpl`
4. The standard CI/CD pipeline runs (`tofu fmt` check, `tofu plan`)
5. Review the plan output — image-only changes will show a userdata hash change (triggering instance recreation)
6. Merge and approve the deployment in GitHub Actions

---

## Troubleshooting

### Renovate is not creating PRs

**Check the dependency dashboard issue** in the repository — Renovate creates a tracking issue that shows pending updates and any errors.

**Check the Renovate app logs** at [app.renovatebot.com/dashboard](https://app.renovatebot.com/dashboard).

**Verify the app is still installed:**
1. Navigate to **github.com/settings/installations** (or the org settings)
2. Confirm the Renovate app shows `ghost-stack` in its repository list

### Renovate is not detecting `compose.yml.tftpl`

The `.tftpl` extension is non-standard — Renovate requires the custom `fileMatch` regex in `renovate.json`. Confirm it is present and the file path matches:

```bash
# From repo root
grep -r "fileMatch" renovate.json
```

### PR branch name does not follow `feature/` convention

The `branchPrefix` in `renovate.json` is set to `feature/renovate-`. If PRs are appearing with a different prefix, check that `renovate.json` has not been overridden by a global Renovate config at the organisation level.

---

## Related Documentation

- [Updating Ghost Docker Images](../../CLAUDE.md#updating-ghost-docker-images) — manual upstream sync workflow
- [Renovate documentation](https://docs.renovatebot.com)
