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

### PR Creation Checklist

After creating a PR with `mcp__github__create_pull_request`, **immediately** assign it:

```
mcp__github__issue_write(
  method: "update",
  owner: "noahwhite",
  repo: "<repo-name>",
  issue_number: <PR number>,
  assignees: ["noahwhite"]
)
```

Do NOT proceed with other tasks until the PR is assigned.

## OpenTofu Formatting

`tofu fmt` is not available in this environment. When editing `.tofu` files, manually verify alignment before committing:

- Within each contiguous group of key-value assignments (separated by blank lines or comments), all `=` signs must align to the **longest key + 1 space**.
- When **adding** a new key, check whether it changes the longest key in its group. If not, the existing alignment is unchanged and the new key must be padded to match.
- When **inserting** a key that is shorter than the longest, count spaces carefully — do not disturb spacing on the lines you didn't change.
- Common mistake: replacing a block of lines changes spacing on untouched lines, causing a fmt failure on keys that were already correctly aligned.

Example: if the longest key is `ghost_admin_domain` (18 chars), all `=` signs align at column 19. Adding `tailscale_tailnet` (17 chars) requires **2 spaces** before `=`, and existing keys must keep their original spacing.

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

### Story Status Lifecycle

Move stories through statuses in this order — **never skip ahead**:

| Status | When to set |
|--------|-------------|
| **Triage** | Newly created, not yet reviewed |
| **Backlog** | Triaged, estimated, assigned — not yet scheduled |
| **In Progress** | Branch created, actively being implemented |
| **In PR Review** | PR open, awaiting review |
| **In Deployment Review** | PR merged — Linear GitHub integration sets this automatically |
| **Done** | All AC verified in deployed environment **AND** all test plan items checked |

**Critical:** Do NOT move to **Done** until:
1. CD pipeline has completed successfully
2. All acceptance criteria have been verified in the deployed environment
3. All test plan items are checked off

### Story Triage Checklist

When triaging a story (moving from Triage → Backlog):
1. Set **status** to `Backlog`
2. Set **priority** (1=Urgent, 2=High, 3=Normal, 4=Low)
3. Set **estimate** (story points)
4. Set **assignee** to Noah White

### User Story Creation Checklist

When creating a user story in Linear with `mcp__linear__create_issue`:

1. **Title must be prefixed with `[User Story]`** (e.g., `[User Story] Configure Tailscale to use one-time auth keys`)
2. Use `team: "ghost-stack"`
3. Apply the `User Story` label: `labels: ["User Story"]`
4. Follow the User Story Template format below for the description

Do NOT proceed until the title prefix is verified.

### Epic/Project Labeling

When creating epics (Linear projects):
- **Name must be prefixed with `[EPIC]`** (e.g., `[EPIC] Ghost Stack Backup & Recovery`)
- Apply the **"Epic"** label to identify it as an epic
- Apply a **t-shirt size label** based on complexity (see sizing guide below)
- **Always set Noah White as the project lead**

### Epic Template

All epics must follow this standard template format (see `[EPIC] Secure Remote Management via Private Networking` for reference):

```markdown
### Goal / Outcome

[One paragraph describing what this epic aims to achieve]

**Business Value:**
[Explain why this work matters - what problem does it solve? What risk does it mitigate? What capability does it enable? How does it benefit the user/business?]

[Additional details about the approach, architecture diagrams, or bullet points expanding on the goals]

---

### Definition of Ready (DoR)

- [ ] Epic goal is clearly articulated and aligns with team/organization objectives
- [ ] Relevant stakeholders are identified
- [ ] Dependencies and constraints are understood
- [ ] Acceptance Criteria (AC) defined at a high level
- [ ] Estimation: T-shirt size or rough timebox assigned

---

### Definition of Done (DoD)

- [ ] All associated stories are completed and accepted
- [ ] All functionality works as expected in the dev/staging environment
- [ ] Documentation is written or updated as needed
- [ ] Monitoring and health checks are validated
- [ ] [Epic-specific completion criteria]
```

**Important:** Do NOT include "Issues / Stories" or "Related Projects or Epics" sections - these are visible via Linear's UI.

### Epic T-Shirt Sizing

Sizes represent **complexity and uncertainty**, not duration. Higher complexity tends to correlate with longer duration, but the size itself measures "how hard is this to figure out and implement" rather than "how many days/weeks."

| Size | Complexity / Effort Description | Typical Time Mapping |
|------|--------------------------------|----------------------|
| **Small (S)** | Well-understood, minor dependencies, low risk | 1-2 sprints (2-4 weeks) |
| **Medium (M)** | Standard feature, some integration, moderate unknowns | 3-4 sprints (1.5-2 months) |
| **Large (L)** | Complex logic, multiple team touchpoints, significant risk | 1 full quarter (~3 months) |
| **Extra Large (XL)** | Cross-departmental, massive architectural shifts | Multiple quarters (needs breakdown) |

**Notes:**
- Time mappings are guidelines derived from historical velocity, not prescriptive targets
- XL epics should be broken down into smaller epics before starting
- Actual duration depends on unknowns discovered during implementation

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

### Spike (Research) Stories

Spikes are time-boxed research tasks used to reduce uncertainty before committing to implementation.

**Key differences from User Stories:**
- **Timeboxed, not estimated** - Use a fixed time limit (e.g., 3 days), not story points
- **Output is knowledge** - Deliverables are findings, recommendations, and Go/No-Go decisions
- **May not produce code** - Success is validated learning, not working software

**Title format:** `[Spike] <research question or goal>`

**Template:**

```markdown
**Spike Summary**

[One sentence describing what we're investigating and why]

**Timebox:** [X days]

---

**✅ Success Criteria**

- [ ] Specific, measurable outcomes
- [ ] Questions answered or blockers identified

---

**📝 Research Questions**

1. [Key question to answer]
2. [Key question to answer]

---

**📦 Deliverables**

- [ ] Proof-of-concept or documentation
- [ ] Go/No-Go recommendation
- [ ] If No-Go: alternative approaches identified

---

**📦 Definition of Done**

- [ ] Success criteria validated (or blockers documented)
- [ ] Findings documented in Linear
- [ ] Go/No-Go decision made
- [ ] Next steps defined
```

**Important:** Do NOT assign story point estimates to spikes. The timebox is the only measure.

## Project Overview

Ghost Stack is an infrastructure-as-code project for deploying a self-hosted Ghost blog on Flatcar Container Linux. The stack runs on Vultr cloud with Cloudflare for DNS/CDN, Caddy as reverse proxy, and uses OpenTofu for infrastructure provisioning.

## Key Technologies

- **OpenTofu**: Infrastructure provisioning (uses `.tofu` file extension, not `.tf`)
- **Flatcar Container Linux**: Immutable container-optimized OS
- **Butane/Ignition**: System configuration for Flatcar (`.bu` files transpile to Ignition JSON)
- **Docker Compose**: Container orchestration on the Ghost instance
- **Caddy**: Reverse proxy with automatic HTTPS
- **Ghost**: Blog platform
- **Bitwarden Secrets Manager**: Infrastructure credentials via `bws` CLI (used by OpenTofu and `infra-shell.sh`)
- **Infisical**: Application secrets management — secrets fetched at instance boot via single-use token auth and written to persistent block storage
- **Tailscale**: Secure SSH access to instances
- **Claude.ai**: AI force multiplier — used throughout the project for infrastructure design, implementation, code review, and documentation

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

- **pr-tofu-fmt-check.yml**: Validates OpenTofu formatting on feature branch pushes
  - Only runs when infrastructure files are modified (path filtering)
- **pr-tofu-plan-develop.yml**: Runs `tofu plan` on PRs to develop, uploads plan artifact
  - Only runs when infrastructure files are modified (path filtering)
- **deploy-dev.yml**: Deploys to dev environment on push to develop
  - Requires manual approval via GitHub environment protection
  - Compares PR plan artifact with current state (drift detection)
  - Runs health checks after deployment
  - Skips deployment when no plan artifact exists (no infra changes in PR)

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

### Full infra shell (requires credentials)
```bash
./docker/scripts/infra-shell.sh
```
Builds the container, retrieves all secrets from Bitwarden, and drops you into an interactive shell with all `TF_VAR_*` variables set. Use this for `tofu plan`, `tofu apply`, etc.

### Format check and tests (no credentials required)
```bash
./docker/scripts/infra-shell.sh --no-secrets
```
Builds the container and drops you into a lightweight shell with no credential retrieval. Use this for `tofu fmt` and `tofu test`:

```bash
# Inside the --no-secrets container:

# Check formatting
./opentofu/scripts/tofu.sh dev fmt

# Run unit tests with mock providers
./opentofu/scripts/tofu.sh dev test
```

Both commands work without any credentials. `tofu test` automatically runs `tofu init -backend=false` and sets a dummy `TAILSCALE_API_KEY` if one is not already present.

### Using the ghost-stack-shell container directly
```bash
docker run -it --rm \
  -v "${PWD}:/home/devops/app" \
  -w /home/devops/app \
  ghcr.io/noahwhite/ghost-stack-shell:latest \
  bash
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

# Ghost compose directory (ephemeral config)
cd /etc/ghost-compose

# Secrets directory (persistent on block storage, written by infisical-secrets-fetch.sh at boot)
ls -la /var/mnt/storage/ghost-compose/secrets/
```

## Ghost Compose Architecture

The Ghost Docker Compose stack uses a **hybrid ephemeral/persistent** approach:

### Ephemeral Components (Deployed via Ignition)

These files are deployed to `/etc/ghost-compose/` at boot time and are versioned in the repository:

| File | Purpose |
|------|---------|
| `compose.yml` | Docker Compose service definitions |
| `.env.config` | Non-secret configuration (domains, paths, mail settings) |
| `caddy/Caddyfile` | Reverse proxy configuration with `{$VAR}` placeholders |
| `caddy/snippets/*` | Caddy configuration snippets (Logging, SecurityHeaders, etc.) |
| `mysql-init/*.sh` | Database initialization scripts |

### Persistent Components (On Block Storage)

These files persist across instance recreations on `/var/mnt/storage/`:

| Path | Purpose |
|------|---------|
| `/var/mnt/storage/ghost-compose/secrets/` | Individual secret files (0600, written by `infisical-secrets-fetch.sh` at boot) |
| `/var/mnt/storage/ghost/upload-data/` | Ghost content uploads |
| `/var/mnt/storage/mysql/data/` | MySQL database files |
| `/var/mnt/storage/caddy/certs/` | Cloudflare origin certificates |

### Configuration Flow

```
OpenTofu Variables → env.config.tftpl → Ignition → /etc/ghost-compose/.env.config
                                                            ↓
Infisical (boot) → infisical-secrets-fetch.sh → /var/mnt/storage/ghost-compose/secrets/
                                                            ↓
                         Docker Compose sources .env.config; mounts individual secret files
```

The Infisical single-use token is provisioned by OpenTofu per deployment and injected into
Ignition. `infisical-secrets-fetch.sh` consumes it once at first boot, writes each secret as
a 0600 file on persistent block storage, and the token is invalidated. Secrets survive reboots
without requiring Infisical availability again. See `docs/runbooks/infisical-secrets.md`.

## Ghost Compose Secrets Management

### File Split Strategy

**`.env.config` (ephemeral — deployed via Ignition, safe for version control):**
- Domain names (DOMAIN, ADMIN_DOMAIN)
- Admin IP for Caddy ACL (ADMIN_IP)
- Mail settings (host, user — not password)
- Data paths (UPLOAD_LOCATION, MYSQL_DATA_LOCATION)
- Backup config (R2_ACCOUNT_ID, R2_DEV_BACKUPS_BUCKET)

**`secrets/` (persistent — individual 0600 files on block storage, written by `infisical-secrets-fetch.sh` at boot):**

| File | Secret |
|------|--------|
| `db_password` | MySQL ghost user password |
| `db_root_password` | MySQL root password |
| `health_check_token` | Caddy health check token |
| `mail_smtp_password` | SMTP password |
| `tinybird_admin_token` | TinyBird workspace admin token |
| `ghost_dev_bckup_r2_access_key_id` | R2 backup access key |
| `ghost_dev_bckup_r2_secret_access_key` | R2 backup secret key |

See `docs/runbooks/infisical-secrets.md` for the full inventory and rotation procedures.

### Security Model

| Risk | Mitigation |
|------|------------|
| Vultr userdata exposure | No secrets in Ignition - only `.env.config` |
| OpenTofu state exposure | No secrets passed through OpenTofu variables |
| Block storage access | File permissions (0600), Tailscale-only SSH |
| Instance compromise | Secrets isolated to individual 0600 files, each rotatable independently |

### Modifying Configuration

**Non-secret changes** (domains, paths, mail settings):
1. Update OpenTofu variables in `opentofu/envs/dev/main.tofu`
2. Create a PR to `develop` — plan CI runs automatically
3. Merge and approve the deployment in GitHub Actions
4. Instance will be recreated with new config

**Secret changes** (passwords, tokens):

Secrets are managed in Infisical and written to block storage at boot — there is no
`.env.secrets` file to edit manually. See `docs/runbooks/infisical-secrets.md` for
provisioning and rotation procedures (including how to update a running instance
without reprovisioning).

## Updating Ghost Docker Images

The Ghost Docker stack is based on [TryGhost/ghost-docker](https://github.com/TryGhost/ghost-docker).

Caddy, MySQL, and `ghost/traffic-analytics` image updates are automated via Renovate — see `docs/runbooks/renovate.md` for setup and operation. Ghost itself (`ghost:6-alpine`) is intentionally unpinned and not tracked by Renovate.

### Current Image Versions

Check `opentofu/modules/vultr/instance/userdata/ghost-compose/compose.yml.tftpl` for current versions:
- Caddy: `caddy:2.10.2-alpine@sha256:...`
- MySQL: `mysql:8.0.44@sha256:...`
- Ghost: `ghost:6-alpine` (unpinned, uses latest 6.x)

### Upstream Sync Workflow

1. **Watch for updates**: Star/watch [TryGhost/ghost-docker](https://github.com/TryGhost/ghost-docker) for Renovate PRs

2. **Check for updates**:
   ```bash
   # Compare with upstream
   curl -sL https://raw.githubusercontent.com/TryGhost/ghost-docker/main/compose.yml | diff - opentofu/modules/vultr/instance/userdata/ghost-compose/compose.yml.tftpl
   ```

3. **Update templates**:
   - Edit `compose.yml.tftpl` with new image tags and SHA256 digests
   - Update Caddyfile or snippets if upstream changed them

4. **Deploy** via CI/CD:
   ```bash
   git checkout -b feature/update-ghost-compose-images
   git add opentofu/modules/vultr/instance/userdata/ghost-compose/
   git commit -m "chore: update Ghost compose image versions"
   git push -u origin feature/update-ghost-compose-images
   ```
   Open a PR to `develop`. The plan CI will run automatically — review the plan output,
   then merge and approve the deployment in GitHub Actions.

### Files to Monitor

| Upstream File | Local Template | What Changes |
|---------------|----------------|--------------|
| `compose.yml` | `compose.yml.tftpl` | Image tags, SHA digests, new services |
| `caddy/Caddyfile` | `caddy/Caddyfile` | Proxy rules, new features |
| `caddy/snippets/*` | `caddy/snippets/*` | Snippet updates |
| `.env.example` | Reference only | New environment variables |

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

### Retriggering a Deployment

`deploy-dev.yml` requires a PR-backed plan artifact — it extracts the PR number from
the merge commit and downloads the plan that ran on that PR. Pushing an empty commit
directly to `develop` fails immediately (no PR number in the commit message). The
**Run workflow** button is also absent because workflows only appear in the UI for
workflows on the default branch (`main`), not `develop`.

**Known issue:** If the instance was manually deleted from Vultr, `tofu plan` will
**error** (not show drift) due to a Vultr provider bug
([#688](https://github.com/vultr/terraform-provider-vultr/issues/688)). Remove it
from state first or the plan CI will fail:

```bash
./opentofu/scripts/tofu.sh dev init
./opentofu/scripts/tofu.sh dev state rm module.vm.vultr_instance.this
```

**To retrigger with a plan**, open a PR with a trivial infra file change:

```bash
git checkout develop && git pull origin develop
git checkout -b feature/retrigger-deployment-YYYY-MM-DD
# Edit the drift recovery comment in opentofu/envs/dev/main.tofu
git add opentofu/envs/dev/main.tofu
git commit -m "chore: retrigger deployment to recover from drift"
git push -u origin feature/retrigger-deployment-YYYY-MM-DD
```

Open a PR to `develop`. The plan CI will run, produce a plan showing the drift, and
the deploy will apply after you merge and approve.

See `docs/runbooks/retrigger-deployment.md` for full details and recovery scenarios.

### Updating Alloy Sysext Version

The Grafana Alloy systemd-sysext image is built automatically by the
[alloy-sysext-build](https://github.com/noahwhite/alloy-sysext-build) repository.

**Automated Pipeline:**
When a new Alloy version is released upstream, the following happens automatically:
1. `check-new-releases.yml` detects the new version (runs daily at midnight UTC)
2. `build-and-publish.yml` builds, signs, and uploads the sysext image to R2
3. A PR is automatically created in this repo with the updated version and hash
4. After PR merge and deployment, the instance runs the new version

**GPG Signature Verification:**
All Alloy sysext images are cryptographically signed. The instance verifies signatures
before installing updates via systemd-sysupdate.

- **Signing Key:** `Alloy Sysext Signing Key <alloy-sysext@separationofconcerns.dev>`
- **Public Key Location:** `/etc/systemd/import-pubring.gpg`
- **Sysupdate Config:** `/etc/sysupdate.alloy.d/alloy.conf` with `Verify=true`
- **Signature Files:** `.asc` files stored alongside images in R2

For GPG key management and rotation, see the
[alloy-sysext-build CLAUDE.md](https://github.com/noahwhite/alloy-sysext-build/blob/main/CLAUDE.md).

**Auto-updates:** Alloy auto-updates are enabled via systemd-sysupdate. When a new
version is published to the R2 bucket, the system will automatically download and
stage the update, flagging for reboot when updates are available.

**How auto-updates work:**
1. A new Alloy release is detected by alloy-sysext-build's daily check workflow
2. CI automatically builds, signs, and uploads the new sysext image to R2
3. CI creates a PR in ghost-stack to update the pinned version in ghost.bu
4. On the running instance, systemd-sysupdate checks R2 hourly for new versions
5. If a newer version is found, it verifies the GPG signature and downloads the update
6. The system flags `/run/reboot-required` for the next reboot window

**Automated PR Details:**
- Branch naming: `feature/update-alloy-sysext-to-{VERSION}`
- Created by: `alloy-sysext-automation` GitHub App
- Commits are verified/signed by GitHub
- PRs are auto-assigned to Noah White

**To manually pin a specific version:**

1. **Trigger a build** in alloy-sysext-build (if not already built):
   ```bash
   gh workflow run build-and-publish.yml --repo noahwhite/alloy-sysext-build \
     -f version=1.14.0
   ```

2. **Get the SHA256 hash** from the build output or download the checksum file:
   ```bash
   curl -s https://ghost-sysext-images.separationofconcerns.dev/alloy-{VERSION}-amd64.raw.sha256
   ```

3. **Update ghost.bu** (`opentofu/modules/vultr/instance/userdata/ghost.bu`):
   - Update the file path: `/opt/extensions/alloy/alloy-{VERSION}-amd64.raw`
   - Update the source URL: `https://ghost-sysext-images.separationofconcerns.dev/alloy-{VERSION}-amd64.raw`
   - Update the hash: `sha256-{HASH}`
   - Update the symlink target in the `links` section

4. **Apply infrastructure changes**:
   ```bash
   ./opentofu/scripts/tofu.sh dev plan
   ./opentofu/scripts/tofu.sh dev apply
   ```

**Verifying Signatures on Instance:**
```bash
# Check sysupdate config
cat /etc/sysupdate.alloy.d/alloy.conf

# List available updates (verifies signatures)
systemd-sysupdate -C alloy list

# Check the public key
cat /etc/systemd/import-pubring.gpg
```

**Note:** Changing the Butane configuration (including the Alloy version) will cause
OpenTofu to destroy and recreate the instance, as the Ignition config is immutable
and only applied on first boot. This is the expected idempotent behavior.

**Important:** Before recreating an instance, remove the old device from Tailscale admin
to prevent naming conflicts. See `docs/runbooks/tailscale-device-cleanup.md` for details.

### Updating Tailscale Sysext Version

Tailscale is installed via systemd-sysext from the [Flatcar sysext-bakery](https://flatcar.github.io/sysext-bakery/tailscale/).

**Auto-updates:** Tailscale auto-updates are enabled via systemd-sysupdate. The system
will automatically download new versions and flag for reboot when updates are available.

**Note:** Tailscale's built-in auto-update (controlled via the admin console) does not
work with sysext installations because the binaries are in a read-only image. Updates
are handled via systemd-sysupdate instead.

**To manually pin a specific version:**

1. **Check available versions** at the sysext-bakery releases:
   - https://github.com/flatcar/sysext-bakery/releases/tag/tailscale

2. **Get the SHA256 hash** from the SHA256SUMS file in the release

3. **Update ghost.bu** (`opentofu/modules/vultr/instance/userdata/ghost.bu`):
   - Update the file path: `/opt/extensions/tailscale/tailscale-v{VERSION}-x86-64.raw`
   - Update the source URL: `https://extensions.flatcar.org/extensions/tailscale-v{VERSION}-x86-64.raw`
   - Update the hash: `sha256-{HASH}`
   - Update the symlink target in the `links` section

4. **Apply infrastructure changes**:
   ```bash
   ./opentofu/scripts/tofu.sh dev plan
   ./opentofu/scripts/tofu.sh dev apply
   ```

**Note:** The Tailscale sysext includes `tailscaled.service` which auto-starts.
A separate `tailscale-auth.service` runs on first boot to authenticate using
the auth key and enable Tailscale SSH.

**Auth Key Security:** The project uses **one-time auth keys** (`reusable = false` in the
`tailscale_tailnet_key` resource). The key is generated automatically by OpenTofu during
`tofu apply` and is invalidated after first use. This prevents key reuse if exposed in
OpenTofu state. See `docs/token-rotation-runbook.md` for details.

**Auth Key Regeneration:** The Tailscale auth key is automatically regenerated whenever
the instance would be replaced. This is controlled by `instance_replacement_hash` in
`opentofu/envs/dev/main.tofu`, which hashes:
- Instance attributes (region, plan, name, firewall_group_id, ssh key)
- Userdata variables (domains, IPs, config values)
- All config files in `opentofu/modules/vultr/instance/userdata/`

**IMPORTANT:** When adding new config files to the instance userdata, you must also add
them to the `instance_replacement_hash` calculation in `opentofu/envs/dev/main.tofu`.
Otherwise, changes to those files won't trigger Tailscale key regeneration, and the
new instance will fail to authenticate with an already-used key.

**Important:** Changing the Tailscale version will recreate the instance. Before applying,
remove the old device from Tailscale admin to prevent naming conflicts (e.g., the new
instance being named `ghost-dev-01-1`). See `docs/runbooks/tailscale-device-cleanup.md`.

### Debugging deployment failures
1. Check GitHub Actions logs
2. SSH to instance and check container logs
3. Caddy logs show request details including headers

### Backup and Restore

Nightly backups of `/var/mnt/storage/` run via `ghost-backup.timer` → `ghost-backup.service`. The service stops ghost-compose, syncs to Cloudflare R2 using `rclone sync` (via `docker run rclone/rclone:1.69.1`), then restarts ghost-compose. Estimated downtime: ~2–3 minutes.

**What is backed up:** `ghost/upload-data/`, `mysql/data/`, `caddy/certs/`, `ghost-compose/`
**Excluded:** `ghost-compose/secrets/**`, `.env.secrets`, `.env.generated`, `sbin/**`

```bash
# Check timer status
tailscale ssh core@ghost-dev-01
sudo systemctl list-timers ghost-backup.timer

# Manually trigger a backup
sudo systemctl start ghost-backup.service & journalctl -u ghost-backup -f

# Verify stack recovered after backup
docker ps --format "table {{.Names}}\t{{.Status}}"
```

**Restore procedure** (after provisioning a new instance via `tofu apply`):

```bash
tailscale ssh core@ghost-dev-01
sudo /opt/bin/ghost-restore.sh
```

The script prompts for confirmation (`Type 'yes' to continue:`), stops ghost-compose, restores from R2, and restarts ghost-compose.

See `docs/runbooks/backup-restore.md` for full details including provisioning steps and troubleshooting.

## Domain
- Production: `separationofconcerns.dev`
- Admin: `admin.separationofconcerns.dev`
