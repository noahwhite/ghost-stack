# Ghost Stack

Infrastructure-as-code for a self-hosted [Ghost](https://ghost.org/) blog running on
immutable [Flatcar Container Linux](https://www.flatcar.org/), provisioned with
[OpenTofu](https://opentofu.org/) and deployed through a GitHub Actions pipeline.

This repository is the companion codebase to **[Ghost in the Stack](https://www.noahwhite.net/soc/ghost-in-the-stack)**,
a blog series that builds the platform from first principles. It began as a lightweight
MVP and has since grown into the full, cloud-native stack described below — automated
deployments, secrets automation, observability, backups, and ActivityPub federation.

> **Scope:** a single-tenant, single-environment (`dev`) deployment. The multi-tenant SaaS
> evolution lives in a separate project; this repo is the single-tenant foundation.

> **⚠️ Retired — compute layer removed.** The Vultr instance, firewall, block storage and
> the Tailscale policy resources have been destroyed and their OpenTofu definitions removed
> from this repo, so they cannot be redeployed. The `separationofconcerns.dev` blog is now
> served by the multi-tenant Officina platform, which owns the apex/`www`/`admin` DNS records
> and the tailnet ACL. What remains here is Cloudflare (Mailgun DNS + `www`), Grafana Cloud,
> PagerDuty, and Infisical. The sections below describe the stack as it was built and are
> kept for the blog series; treat them as history, not as deploy instructions.

---

## Architecture at a glance

| Layer | Technology |
|-------|-----------|
| Provisioning | OpenTofu (`.tofu` files), modular per-provider |
| Host OS | Flatcar Container Linux (immutable), configured via Butane → Ignition |
| Runtime | Docker Compose on the host — Ghost, MySQL, Caddy, ActivityPub, Traffic Analytics |
| Reverse proxy / TLS | Caddy (automatic HTTPS, security headers, health-check gating) |
| DNS / CDN / state | Cloudflare (DNS, edge, R2 bucket for remote OpenTofu state) |
| Cloud host | Vultr (instance, firewall, block storage) |
| Infra secrets | Bitwarden Secrets Manager (`bws`), injected at runtime — never on disk |
| App secrets | Infisical, fetched at boot via single-use token, written to block storage |
| Remote access | Tailscale (SSH is Tailscale-only; no public SSH) |
| Observability | Grafana Cloud (metrics/logs) + PagerDuty (alerting) |
| Backups | Scheduled backups to R2 with tiered retention |
| CI/CD | GitHub Actions — fmt-check, plan-on-PR, gated deploy-on-merge |

Persistent state (MySQL data, Ghost content, secrets) lives on Vultr block storage and
survives host rebuilds; everything else is delivered immutably via Ignition on each deploy.

---

## Repository structure

```
ghost-stack/
├── CLAUDE.md                     # Full engineering context and operational runbook
├── README.md
├── LICENSE
├── docker/
│   ├── Dockerfile                # ghost-stack-shell image (OpenTofu 1.11.1 + tooling)
│   ├── ghost6/compose.yml        # Reference Ghost 6 compose definition
│   └── scripts/
│       ├── infra-shell.sh        # Interactive shell with secrets injected from Bitwarden
│       └── bootstrap-infra-shell.sh
├── opentofu/
│   ├── envs/dev/                 # Dev environment root module (main.tofu, tests/)
│   ├── modules/
│   │   ├── cloudflare/dns_records/
│   │   ├── grafana-cloud/
│   │   ├── infisical/
│   │   └── pagerduty/
│   ├── bootstrap/                # One-time R2 state bucket + Cloudflare zone provisioning
│   └── scripts/
│       └── tofu.sh               # Wrapper: ./tofu.sh <env> <plan|apply|fmt|test>
├── docs/                         # Runbooks and workflow documentation
├── keys/                         # Public SSH key(s) only
└── soc-cms/                      # CMS content redirects
```

The Ghost host's Docker Compose stack, Caddy config, and boot scripts lived under
`opentofu/modules/vultr/instance/userdata/`, removed with the compute layer. See the git
history if you need them.

---

## Getting started

### Prerequisites

- A registered domain (this project uses `separationofconcerns.dev`)
- A Cloudflare account (DNS + R2 enabled)
- A Vultr account
- A Bitwarden Secrets Manager account with a machine access token (`BWS_ACCESS_TOKEN`)
- Docker (all tooling runs inside a container — nothing is installed on the host)

### 1. Bootstrap the foundation (once per environment)

Before the main stack can be deployed, a one-time bootstrap provisions the Cloudflare R2
bucket that stores OpenTofu remote state and the Cloudflare DNS zone. Follow
[`opentofu/bootstrap/README.md`](opentofu/bootstrap/README.md).

### 2. Delegate the domain to Cloudflare

The bootstrap apply outputs two Cloudflare nameservers. Set these as the custom nameservers
at your registrar to delegate DNS control to Cloudflare.

### 3. Work locally in the containerized shell

All OpenTofu commands run inside the `ghost-stack-shell` container so the host stays clean
and secrets are injected at runtime rather than written to disk.

```bash
# Full shell — builds the image and injects all secrets from Bitwarden
./docker/scripts/infra-shell.sh

# No-credentials shell — for fmt and tests only
./docker/scripts/infra-shell.sh --no-secrets
```

Inside the container, use the wrapper script:

```bash
./opentofu/scripts/tofu.sh dev fmt      # Format check
./opentofu/scripts/tofu.sh dev test     # Unit tests (mock providers, no credentials)
./opentofu/scripts/tofu.sh dev plan     # Plan against dev
./opentofu/scripts/tofu.sh dev apply    # Apply to dev
```

`fmt` and `test` require no credentials, so `--no-secrets` is enough for local validation.

---

## Secrets

Two separate systems, by design (details in [`docs/secrets-management.md`](docs/secrets-management.md)):

- **Bitwarden Secrets Manager** holds infrastructure credentials (Cloudflare, Vultr,
  Tailscale, Grafana, PagerDuty). They are fetched at runtime by `infra-shell.sh` and CI,
  exported as `TF_VAR_*`, and never committed.
- **Infisical** holds application secrets for Ghost. The instance fetches them at boot with
  a single-use token and writes them to persistent block storage.

No secret values live in git, cloud-init, or Butane. The reference IDs in the secrets docs
are pointers into Bitwarden, not the secrets themselves.

---

## CI/CD

Three GitHub Actions workflows drive infrastructure changes (plus `claude-review.yml` for
automated PR review). `sync-tryghost-compose.yml` was removed with the compute layer — it
existed only to track upstream Ghost images into the host's compose template:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `pr-tofu-fmt-check.yml` | PR push (infra paths) | Enforce `tofu fmt` |
| `pr-tofu-plan-develop.yml` | PR to `develop` (infra paths) | Run `tofu plan`, upload plan artifact |
| `deploy-dev.yml` | Push to `develop` | Gated deploy: replays the PR plan, drift-checks, health-checks |

Deploys require manual approval via GitHub environment protection and skip automatically
when a PR contains no infrastructure changes. See
[`docs/automated-deployment-workflow.md`](docs/automated-deployment-workflow.md) for the
full pipeline and [`docs/git-workflow-mvp.md`](docs/git-workflow-mvp.md) for the branching
model.

---

## Documentation

- [`CLAUDE.md`](CLAUDE.md) — the complete engineering and operations reference for this repo
- [`docs/automated-deployment-workflow.md`](docs/automated-deployment-workflow.md) — the CI/CD pipeline in detail
- [`docs/secrets-management.md`](docs/secrets-management.md) — the two-tier secrets model
- [`docs/branch-protection-rules.md`](docs/branch-protection-rules.md) — branch protection setup
- [`docs/runbooks/`](docs/runbooks/) — backup/restore, secrets migration, Renovate, Tailscale cleanup, Tinybird analytics, and more

---

## License

See [`LICENSE`](LICENSE).
