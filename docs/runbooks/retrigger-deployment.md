# Runbook: Retriggering a Deployment

## Overview

This runbook covers how to retrigger the `deploy-dev.yml` CI/CD pipeline when you need
to redeploy without a code change — for example, after manually recovering from a
transient infrastructure failure.

## Background

### Why the "Run workflow" Button Doesn't Appear

`deploy-dev.yml` has a `workflow_dispatch` trigger in its YAML, but GitHub only shows
the **Run workflow** button in the UI for workflows that exist on the repository's
**default branch**. The default branch is `main`, which is sparse (only contains GitHub
issue templates). All CI/CD workflows live on `develop`, so the button is never shown.

**Workaround:** Push an empty commit to `develop` to trigger the `push` event.

## When to Use This Runbook

- A transient Vultr infrastructure failure required manual instance deletion (e.g., block
  storage failed to attach on first boot)
- The OpenTofu state has drifted from actual infrastructure after manual recovery
- You need to redeploy without making a code change
- A deployment was cancelled and needs to be re-run

## Procedure

### 1. Verify Current State

Before retriggering, confirm the state is what you expect:

```bash
# Check the latest workflow runs
gh run list --repo noahwhite/ghost-stack --workflow=deploy-dev.yml --limit 5

# If you have infra access, check for drift
./opentofu/scripts/tofu.sh dev plan
```

### 2. Retrigger via Empty Commit

```bash
git checkout develop
git pull origin develop
git commit --allow-empty -m "chore: retrigger deployment"
git push origin develop
```

### 3. Approve the Deployment

1. Go to https://github.com/noahwhite/ghost-stack/actions/workflows/deploy-dev.yml
2. Click the running workflow
3. Approve the deployment when the environment protection prompt appears

### 4. Monitor the Deployment

Watch the workflow logs for:
- **Drift detection step**: Will show the diff between stored plan and current state.
  After a manual instance deletion, this will show the instance as needing creation —
  that is expected.
- **Apply step**: Should recreate the missing resource(s)
- **Health check step**: Confirms the instance is up and responding

## Recovery Scenarios

### Block Storage Failed to Attach (Vultr Flakiness)

This is a known intermittent Vultr issue where block storage fails to attach during
instance creation, leaving the instance in an emergency shell at boot.

**Symptoms:**
- Instance is reachable via Vultr console but drops to emergency shell
- `journalctl -b` shows block storage mount failure
- Tailscale SSH is not available (Ignition didn't complete)

**Resolution:**
1. Check whether Tailscale auth ran before the failure:
   ```bash
   # In the emergency shell via Vultr VNC console
   systemctl status tailscale-auth.service
   ```
2. If Tailscale auth did not run (likely), skip device cleanup — no stale device was registered
3. If Tailscale auth ran, remove the device from the Tailscale admin console first.
   See `docs/runbooks/tailscale-device-cleanup.md`
4. Delete the instance from the Vultr console (**do not delete the block storage**)
5. Retrigger the deployment using the empty commit procedure above

### Deployment Cancelled Mid-Apply

If a deployment was cancelled while `tofu apply` was running, state may be partially
updated.

**Resolution:**
1. Run `tofu plan` inside the infra-shell to assess the actual drift
2. If safe, retrigger via empty commit — the apply will converge to the desired state
3. If state is corrupted, manually reconcile before retriggering

## Related Documentation

- Tailscale Device Cleanup: `docs/runbooks/tailscale-device-cleanup.md`
- CI/CD Workflows: See "CI/CD Workflows" section in `CLAUDE.md`
- Running Locally: See "Running Locally" section in `CLAUDE.md`
