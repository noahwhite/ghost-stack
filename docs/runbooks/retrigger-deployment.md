# Runbook: Retriggering a Deployment

## Overview

This runbook covers how to retrigger the `deploy-dev.yml` CI/CD pipeline when you need
to deploy without a meaningful code change — for example, after manually recovering from
a transient infrastructure failure that left OpenTofu state out of sync with Vultr.

## Background

### How deploy-dev.yml works

`deploy-dev.yml` is strict about requiring a PR-backed plan:

1. **Extracts PR number** from the merge commit message (e.g., `(#123)`) — fails if absent
2. **Downloads plan artifact** from `pr-tofu-plan-develop.yml` that ran on that PR
3. **Skips deployment** if no plan artifact exists (docs-only PRs, empty commits)
4. **Compares** the stored PR plan against a fresh plan to detect drift since approval
5. **Applies** only if both plans match

### Why the "Run workflow" Button Doesn't Appear

`deploy-dev.yml` has a `workflow_dispatch` trigger, but GitHub only shows the **Run
workflow** button for workflows present on the **default branch** (`main`). All CI
workflows live on `develop`, so the button is never available.

### Why an empty commit doesn't work

Pushing an empty commit directly to `develop` fails at step 1 above — the commit
message has no `(#XXX)` PR reference, so `deploy-dev.yml` exits immediately with
"No PR number found in commit message".

## Correct Procedure: Open a PR with an Infra File Touch

The only reliable way to retrigger is to open a PR that touches at least one file
matching the `pr-tofu-plan-develop.yml` path filter. This causes the plan CI to run,
generates a plan artifact, and lets the deploy proceed after merge.

**Files that trigger the plan CI (path filter):**
```
opentofu/**/*.tofu
opentofu/**/*.bu
opentofu/**/*.tftpl
opentofu/**/*.sh
opentofu/**/userdata/**
docker/scripts/**
.github/workflows/pr-tofu-*.yml
.github/workflows/deploy-dev.yml
```

### Steps

**1. Create a branch and make a trivial infra change**

A comment change in any `.tofu` file is sufficient. The drift recovery note in
`opentofu/envs/dev/main.tofu` was added specifically for this purpose — update
the date or add a line to use it as the trigger:

```bash
git checkout develop && git pull origin develop
git checkout -b feature/retrigger-deployment-YYYY-MM-DD
```

Edit `opentofu/envs/dev/main.tofu` — add or update the comment in the
"Drift Recovery Note" block near the top of the `locals {}` section.

**2. Push and open a PR to develop**

```bash
git add opentofu/envs/dev/main.tofu
git commit -m "chore: retrigger deployment to recover from drift"
git push -u origin feature/retrigger-deployment-YYYY-MM-DD
```

Open a PR targeting `develop`. `pr-tofu-plan-develop.yml` will run automatically
and generate a plan artifact showing the drift (e.g., instance needs to be created).

**3. Review the plan**

The plan output will appear as a PR comment. Verify it shows the expected changes
(e.g., `1 to add, 0 to change, 0 to destroy` for the missing instance).

**4. Merge the PR and approve the deployment**

Merge the PR. `deploy-dev.yml` will:
- Download the PR plan artifact
- Generate a fresh plan (should match, since the instance is still missing)
- Prompt for environment approval
- Apply once approved

Approve the deployment in the GitHub Actions UI when prompted.

## Recovery Scenarios

### Block Storage Failed to Attach (Vultr Flakiness)

This is a known intermittent Vultr issue where block storage fails to attach during
instance creation, leaving the instance in an emergency shell at boot.

**Symptoms:**
- Instance is reachable via Vultr VNC console but drops to emergency shell
- `journalctl -b` shows block storage mount failure
- Tailscale SSH is unavailable (Ignition didn't complete)

**Resolution:**

1. Check whether Tailscale auth ran before the failure:
   ```bash
   # In the emergency shell via Vultr VNC console
   systemctl status tailscale-auth.service
   ```

2. If Tailscale auth did not run (likely), skip device cleanup — no device was
   registered. If it did run, remove the device from Tailscale admin first.
   See `docs/runbooks/tailscale-device-cleanup.md`.

3. Delete the instance from the Vultr console. **Do not delete the block storage.**

4. Remove the instance from OpenTofu state (see "Vultr Provider Bug" below), then
   follow the "Correct Procedure" above to open a PR, get a plan, and deploy.

### Vultr Provider Bug: Plan Errors Instead of Planning Recreation

**Issue:** [vultr/terraform-provider-vultr#688](https://github.com/vultr/terraform-provider-vultr/issues/688)

When a `vultr_instance` is deleted outside of OpenTofu (e.g., via the Vultr console),
`tofu plan` **errors out** instead of detecting the missing resource and planning to
recreate it:

```
│ Error: error getting instance (xxxx-xxxx): {"error":"instance not found","status":404}
│
│   with module.vm.vultr_instance.this,
```

This means the plan CI on any PR will fail until the stale state entry is removed.

**Workaround — remove the instance from state before planning:**

```bash
# From inside the infra-shell
./opentofu/scripts/tofu.sh dev init
./opentofu/scripts/tofu.sh dev state rm module.vm.vultr_instance.this
```

After `state rm`, `tofu plan` will show the instance as `1 to add` and the plan CI
on your retrigger PR will succeed.

**Important:** `state rm` must be run before opening the retrigger PR, otherwise the
plan CI job will fail with the provider error.

### Deployment Cancelled Mid-Apply

If a deployment was cancelled while `tofu apply` was running, state may be partially
updated.

1. Run `tofu plan` inside the infra-shell to assess actual drift:
   ```bash
   ./opentofu/scripts/tofu.sh dev plan
   ```
2. If safe, follow the "Correct Procedure" above — the apply will converge to the
   desired state.
3. If state is corrupted, manually reconcile before retriggering.

## Related Documentation

- Tailscale Device Cleanup: `docs/runbooks/tailscale-device-cleanup.md`
- CI/CD Workflows: See "CI/CD Workflows" section in `CLAUDE.md`
- Drift Recovery Note in code: `opentofu/envs/dev/main.tofu` (`locals {}` block)
