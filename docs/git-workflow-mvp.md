# Git Workflow

This project runs a single environment (`dev`) with a pull-request-based workflow and an
automated GitHub Actions deployment pipeline. This document describes the branching model;
for the deployment pipeline itself, see [`automated-deployment-workflow.md`](automated-deployment-workflow.md).

## Goals

- Support solo or small-team iteration with GitHub as the source of truth
- Ensure reproducibility of infrastructure using OpenTofu
- Keep `develop` deployable at all times behind a gated pipeline
- Manage secrets outside of git via Bitwarden Secrets Manager, injected at runtime

---

## Branch Structure

| Branch      | Purpose                                                          |
|-------------|-----------------------------------------------------------------|
| `main`      | Protected base branch; long-lived                               |
| `develop`   | Integration branch — merges here trigger the gated dev deploy   |
| `feature/*` | Short-lived branches (`feature/GHO-XX-short-description`)        |

Both `main` and `develop` are protected: changes land via pull request, and commits must be
verified (signed). See [`branch-protection-rules.md`](branch-protection-rules.md).

---

## Local Development Process

1. **Clone the repo**:

   ```bash
   git clone https://github.com/noahwhite/ghost-stack.git
   cd ghost-stack
   ```

2. **Create a feature branch**:

   ```bash
   git checkout -b feature/GHO-XX-short-description
   ```

3. **Make changes** to OpenTofu modules or documentation.

4. **Commit and push** the feature branch, then open a PR against `develop`:

   ```bash
   git add .
   git commit -m "Add Vultr VM for Ghost app server"
   git push origin feature/GHO-XX-short-description
   ```

   Do not push directly to `develop` or `main` — both are protected and require a PR with a
   verified (signed) commit.

---

## Deployment

Infrastructure changes are validated and deployed automatically:

- Opening a PR against `develop` runs `tofu fmt` and `tofu plan`, uploading the plan as an
  artifact (infrastructure paths only).
- Merging to `develop` triggers `deploy-dev.yml`, which replays the PR plan, checks for
  drift, applies behind a manual approval gate, and runs post-deploy health checks.

See [`automated-deployment-workflow.md`](automated-deployment-workflow.md) for the full
pipeline.

---

## Running OpenTofu Locally

Infrastructure tooling runs inside the `ghost-stack-shell` container so the host stays clean
and secrets are injected at runtime.

### Run the Dev Shell

```bash
# Full shell — secrets injected from Bitwarden Secrets Manager
./docker/scripts/infra-shell.sh

# No-credentials shell — for fmt and tests only
./docker/scripts/infra-shell.sh --no-secrets
```

The container provides OpenTofu 1.11.1 plus standard CLI tooling.

### Plan and Apply

Use the wrapper script, which selects the environment (there is no `-var-file` to pass;
`dev.auto.tfvars` was removed with the compute layer — all remaining inputs come from
`TF_VAR_*` supplied by `infra-shell.sh` or CI):

```bash
./opentofu/scripts/tofu.sh dev fmt      # Format check (no credentials)
./opentofu/scripts/tofu.sh dev test     # Unit tests with mock providers (no credentials)
./opentofu/scripts/tofu.sh dev plan     # Plan against dev
./opentofu/scripts/tofu.sh dev apply    # Apply to dev
```

Before planning or applying against real infrastructure, read
[`secrets-management.md`](secrets-management.md) to set up the required secrets.

---

## Future Evolution

Additional environments (staging, production) and promotion logic would introduce further
branches and workflows. The multi-environment, multi-tenant evolution of this platform is
tracked in a separate project.

---

📁 _This document lives at `docs/git-workflow-mvp.md` in the repository._
