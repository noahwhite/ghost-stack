# CLAUDE.md - Project Context for Claude Code

## Role

You are a staff-level infrastructure and application engineer/architect. Provide thorough, well-reasoned solutions with attention to security, maintainability, and operational excellence.

## Communication Standards

- All commit messages should be clear and descriptive
- All PR comments must be formatted in markdown
- Use todo lists to track multi-step tasks
- **Never add "Generated with Claude Code" or similar attribution lines to PRs or commits**
- **Never add Co-Authored-By lines to commits**
- **Always create PRs instead of committing directly to main or protected branches**
- **Always assign PRs to Noah White**

## Testing Requirements

- Infrastructure tests must be added when modifying OpenTofu/infrastructure code
- Tests use `.tofutest.hcl` extension
- Current tests are in `opentofu/envs/dev/tests/`
- Follow existing test patterns (see `grafana-cloud.tofutest.hcl`, `vultr-firewall.tofutest.hcl`, `tailscale.tofutest.hcl`)
- When staging and prod environments are added, tests will follow the same pattern under `opentofu/envs/<env>/tests/`

## Linear Integration

- **Always set Noah White as the project lead** when creating new projects
- Use the `ghost-stack` team for all issues and projects
- Include detailed acceptance criteria in issue descriptions
- Link related issues using dependencies where applicable

### Epic/Project Labeling

When creating epics (Linear projects):
- Apply the **"Epic"** label to identify it as an epic
- Apply a **t-shirt size label** based on total story points:
  - T-Shirt Size Small: ~5-10 story points
  - T-Shirt Size Medium: ~15-25 story points
  - T-Shirt Size Large: ~30+ story points
- Reference: See `[EPIC] Secure Remote Management via Private Networking` as an example

### User Story Template

All user stories must follow this standard template format (see GHO-21 for reference):

```markdown
**Story Summary**

As a [role], I want [feature/capability], so that [business value].

---

**✅ Acceptance Criteria**

- [ ] Clear, testable criteria
- [ ] Use Given/When/Then format if applicable

---

**📝 Additional Context**

* Design: [Design considerations or approach]
* Docs: [Documentation to update or reference]
* Related Issues/PRs: [Links and dependencies]

---

**📦 Definition of Ready**

- [ ] Acceptance criteria defined
- [ ] No unresolved external dependencies
- [ ] Story is estimated
- [ ] Team has necessary skills and access
- [ ] Priority is clear
- [ ] Business value understood

---

**✅ Definition of Done**

- [ ] All acceptance criteria met
- [ ] Unit/integration tests written & passing
- [ ] Peer-reviewed
- [ ] Docs updated (if applicable)
- [ ] Verified in staging (if needed)
- [ ] No critical bugs/regressions
```

## Project Overview

Ghost Stack is an infrastructure-as-code project for deploying a self-hosted Ghost blog on Flatcar Container Linux. The stack runs on Vultr cloud with Cloudflare for DNS/CDN, Caddy as reverse proxy, and uses OpenTofu for infrastructure provisioning.

## Key Technologies

- **OpenTofu**: Infrastructure provisioning (uses `.tofu` file extension, not `.tf`)
- **Flatcar Container Linux**: Immutable container-optimized OS
- **Butane/Ignition**: System configuration for Flatcar (`.bu` files transpile to Ignition JSON)
- **Docker Compose**: Container orchestration on the Ghost instance
- **Caddy**: Reverse proxy with automatic HTTPS
- **Ghost**: Blog platform
- **Bitwarden Secrets Manager**: Secrets management via `bws` CLI
- **Tailscale**: Secure SSH access to instances

## Repository Structure

```
.github/workflows/       # CI/CD workflows
docker/
  ghost6/               # Docker Compose configuration for Ghost stack
  scripts/              # Shell scripts (infra-shell.sh, tofu.sh)
  Dockerfile            # ghost-stack-shell container image
opentofu/
  envs/dev/             # Dev environment configuration
  modules/              # Reusable OpenTofu modules
    vultr/              # Vultr instance, firewall, block storage
    cloudflare/         # DNS records
    tailscale/          # Tailscale device registration
    grafana-cloud/      # Observability
    pagerduty/          # Alerting
  bootstrap/            # Bootstrap infrastructure (R2, Cloudflare zone)
  scripts/              # tofu.sh wrapper script
docs/                   # Documentation
```

## CI/CD Workflows

- **pr-tofu-fmt-check.yml**: Validates OpenTofu formatting on PRs
- **pr-tofu-plan-develop.yml**: Runs `tofu plan` on PRs to develop, uploads plan artifact
- **deploy-dev.yml**: Deploys to dev environment on push to develop
  - Requires manual approval via GitHub environment protection
  - Compares PR plan artifact with current state (drift detection)
  - Runs health checks after deployment

## Important Patterns

### Secrets Management
- **Environment-scoped secrets**: Used by both PR and deploy workflows (e.g., `BWS_ACCESS_TOKEN`, `ADMIN_IP`, `CLOUDFLARE_ZONE_ID`)
- **Repository-level secrets**: Only `GHCR_TOKEN` remains at repository level (for workflows without environment)
- **Bitwarden Secrets Manager**: Retrieves secrets at runtime via `infra-shell.sh`
- See `docs/token-rotation-runbook.md` for complete token inventory and rotation procedures

### OpenTofu Wrapper Script
Use `./opentofu/scripts/tofu.sh` instead of `tofu` directly:
```bash
./opentofu/scripts/tofu.sh dev plan    # Plan for dev environment
./opentofu/scripts/tofu.sh dev apply   # Apply to dev environment
```

### Health Checks
- Health check requests use `X-Health-Check-Token` header for authentication
- Token stored in GitHub Secrets (`HEALTH_CHECK_TOKEN`)
- Caddy validates token before allowing access
- Token is redacted from Caddy logs

### Firewall Rules
- HTTP/HTTPS allowed from Cloudflare edge IPs and admin workstation IP
- SSH only via Tailscale
- GitHub Actions IPs not directly allowed (requests go through Cloudflare)

## Running Locally

### Using the ghost-stack-shell container
```bash
docker run -it --rm \
  -v "${PWD}:/home/devops/app" \
  -w /home/devops/app \
  ghcr.io/noahwhite/ghost-stack-shell:latest \
  bash
```

### Format checking
```bash
tofu fmt -check -recursive opentofu/
```

## Ghost Instance Access

```bash
# SSH via Tailscale
tailscale ssh core@ghost-dev-1

# View container logs
docker logs ghost-compose-caddy-1
docker logs ghost-compose-ghost-1

# Reload Caddy config (use restart if reload doesn't work)
docker exec ghost-compose-caddy-1 caddy reload --config /etc/caddy/Caddyfile
docker restart ghost-compose-caddy-1

# Ghost compose directory
cd /var/mnt/storage/ghost-compose
```

## Branch Naming Convention

**All feature branches must follow the `feature/**` pattern** (e.g., `feature/GHO-XX-description`).

This naming convention is recommended for consistency and traceability.

### GitHub Environments
- **`dev`**: Protected environment for actual deployments. Only `develop` branch can deploy. Used by `deploy-dev.yml`.
- **`dev-ci`**: Shadow environment for PR validation. No branch restrictions. Used by `pr-tofu-plan-develop.yml` for `tofu plan` checks. Has required reviewers for security (public repo).

Examples of valid branch names:
- `feature/GHO-42-add-token-rotation-runbook`
- `feature/add-new-module`
- `feature/fix-firewall-rules`

## Common Tasks

### Creating a new feature
1. Create branch from develop: `git checkout -b feature/GHO-XX-description`
2. Make changes
3. Push and create PR to develop
4. PR checks run automatically (fmt, plan)
5. Merge triggers deployment (requires approval)

### Debugging deployment failures
1. Check GitHub Actions logs
2. SSH to instance and check container logs
3. Caddy logs show request details including headers

## Domain
- Production: `separationofconcerns.dev`
- Admin: `admin.separationofconcerns.dev`
