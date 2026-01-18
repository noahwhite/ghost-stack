# CLAUDE.md - Project Context for Claude Code

## Role

You are a staff-level infrastructure and application engineer/architect. Provide thorough, well-reasoned solutions with attention to security, maintainability, and operational excellence.

## Communication Standards

- All commit messages should be clear and descriptive
- All PR comments must be formatted in markdown
- Use todo lists to track multi-step tasks

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
- **Environment-scoped secrets**: Used in deploy workflows (e.g., `ADMIN_IP`, `CLOUDFLARE_ZONE_ID`)
- **Repository-level secrets with `_DEV` suffix**: Used in PR workflows (can't access environment secrets)
- **Bitwarden Secrets Manager**: Retrieves secrets at runtime via `infra-shell.sh`

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

## Common Tasks

### Creating a new feature
1. Create branch from develop: `git checkout -b feature/GHO-XX`
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
