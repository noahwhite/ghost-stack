# Git Workflow: MVP / Dev-Only Stage

This project currently operates in a single-environment setup: **`dev` only**. As the infrastructure evolves, we'll adopt additional environments (staging, production), but this document describes the initial development workflow for the MVP phase.

## Goals of the MVP Git Workflow

- Support **solo or small-team iteration**
- Ensure reproducibility of infrastructure using OpenTofu
- Leverage a clean branch model with GitHub as the source of truth
- Provide a foundation for future CI/CD and environment promotion
- Secrets stored in **1Password GUI** (or your tool of choice), injected at runtime

---

## Branch Structure

| Branch    | Purpose                                       |
|-----------|-----------------------------------------------|
| `develop` | Primary working branch for infrastructure code |
| `feature/*` | Optional short-lived branches for new resources or blog content |

> There is **no `main` branch used yet** in this phase. All deployments come from `develop`.

---

## Local Development Process

1. **Clone the repo**:

   ```bash
   git clone https://github.com/noahwhite/ghost-stack-part1.git
   cd ghost-stack-part1
   ```

2. **Create a feature branch** (optional):

   ```bash
   git checkout -b feature/setup-vultr-vm
   ```

3. **Make changes** to OpenTofu/Terraform modules or blog content.

4. **Commit and push** to `develop`:

   ```bash
   git add .
   git commit -m "Add Vultr VM for Ghost app server"
   git push origin develop
   ```

---

## Deployment

Infrastructure is managed manually using the Docker-based development shell.

### Run the Dev Shell

```bash
./docker/scripts/infra-shell.sh
```

This shell provides:

- OpenTofu (1.10.5)
- Ubuntu base image
- Standard CLI tools (`curl`, `git`, etc.)

---

## Secrets Management

Before applying the infrastructure read [`Secrets Management`](secrets-management.md) for setting up and managing the required secrets.

---

## Apply Infrastructure

Once secrets are loaded in the current shell session:

```bash
cd opentofu/envs/dev
tofu init
tofu plan -var-file=dev.tfvars
tofu apply -var-file=dev.tfvars
```

---

## Future Evolution

Once staging and production environments are introduced, this workflow will evolve to include:

- Additional branches (`staging`, `main`)
- CI/CD pipelines with GitHub Actions
- Promotion logic via pull requests
- Secrets managed via automation or external vaulting tools

Stay tuned in future parts of the series.

---

📁 _This document lives at `docs/git-workflow-mvp.md` in the repository._