
# Ghost Stack (Part 1)

This repository represents the initial phase of a modular, infrastructure-as-code deployment for a self-hosted Ghost blog. It targets a single environment (dev) using Vultr and Cloudflare, and is bootstrapped with OpenTofu.

## Project Overview

- IaC powered by [OpenTofu](https://opentofu.org/)
- Target environment: `dev`
- Infrastructure hosted on:
  - Vultr (Ghost App Server)
  - Cloudflare (DNS, R2 for state storage)
- Manual secret management using 1Password GUI
- Optional containerized tooling for a clean host experience

---

## Getting Started

### Prerequisites

- A domain name purchased via a registrar (e.g., Porkbun, Namecheap)
- A Cloudflare account (scoped to the dev environment)
- A Vultr account (scoped to the dev environment)
- [1Password](https://1password.com/) or other similar tool, for secure local secret management
- Docker (for isolated tooling)

---

## Directory Structure

```
ghost_stack_part1/
├── README.md
├── docker/
│   ├── Dockerfile
│   └── scripts/
│       └── infra-shell.sh
└── opentofu/
    ├── envs/
    │   └── dev/
    │       ├── backend.tf
    │       ├── dev.tfvars.example
    │       ├── main.tf
    │       ├── prod.tfvars
    │       └── variables.tf
    ├── modules/
    │   ├── cloudflare/
    │   │   └── dns/
    │   │       ├── dns.tf
    │   │       ├── outputs.tf
    │   │       └── variables.tf
    │   └── vultr/
    │       └── vm/
    │           ├── cloud-init.yml.tpl
    │           ├── outputs.tf
    │           ├── variables.tf
    │           └── vultr-instance.tf
    ├── scripts/
    │   ├── apply_dev.sh
    │   ├── init-dev.sh
    │   └── plan_dev.sh
    └── bootstrap/
        ├── README.md
        ├── scripts/
        ├── envs/
        │   └── dev/
        │       ├── cloudflare_zone.tf
        │       └── r2.tf
        └── modules/
            ├── cloudflare_zone/
            │   ├── main.tf
            │   └── outputs.tf
            └── r2/
                ├── main.tf
                ├── README.md
                └── variables.tf
```

---

## Using the Infrastructure Shell

This project provides a containerized shell for managing infrastructure.

To build and use the container:

```bash
cd docker
docker build -t ghost_stack_shell .
../scripts/infra-shell.sh
```

The shell includes:
- OpenTofu (1.10.5)
- curl, unzip, git, bash

---

## Secrets Management

Secrets are stored in 1Password (GUI) because we already use this tool. You could use any number of similar tools to manage them. In later iterations we will shift to them being managed by infrastructure levereged by the CI/CD pipeline. To use them:

1. Retrieve the following from your 1Password vault (or your tool of choice):
   - Cloudflare API Token
   - Cloudflare Account ID
   - Vultr API Key
2. Run the secure loader script:

```bash
eval $(./scripts/load-dev-secrets.sh)
```

Secrets are only used in memory and never written to disk.

---


### Cloudflare Credential Strategy

This project uses **scoped Cloudflare API tokens** to provision DNS, object storage, and other Cloudflare infrastructure through OpenTofu. These tokens:

- Are created manually through the Cloudflare dashboard
- Are scoped to specific accounts, zones, and permissions (e.g., DNS:Edit, Zone:Read, R2:Edit)

#### Why not use the Cloudflare global API key?

The **Cloudflare global API key** is _not used_ for routine infrastructure operations. However, it _may be required_ temporarily if you choose to:

- Automate the creation of scoped API tokens
- Script token lifecycle management (will address at a later stage)

By default, this project assumes you **manually create and rotate** scoped API tokens for this development environment). This strikes a balance between **security**, **provider compatibility**, and **simplicity** in development.


#### Recommended Cloudflare API Token(s)

| Name                   | Permissions                                                  | Resources                     | Purpose                                         |
| ---------------------- | ------------------------------------------------------------ | ----------------------------- | ----------------------------------------------- |
| `cloudflare-dev-token` | - Zone:Read<br>- Zone:Edit<br>- DNS:Edit<br>- Account Settings:Read | Dev account + zone only       | For provisioning DNS records and creating zones |
| `r2-state-token`       | - Account Storage Buckets:Edit                               | Dev account (R2 bucket scope) | For managing Terraform state in R2              |

Use the Cloudflare dashboard to [create custom API tokens](https://dash.cloudflare.com/profile/api-tokens) with scoped permissions.

---

## Obtain A Domain For The Development Environment

1. Purchase a domain name (e.g., from Porkbun) for the dev environment. We picked **separationofconcerns.dev**
2. Continue with the bootstrap process

------

## Bootstrapping

Before running the main infrastructure, you must do a one time provisioning of:

- A Cloudflare R2 bucket (for OpenTofu state)
- A Cloudflare zone (for your domain) to facilitate domain delegation

To bootstrap:

```bash
eval $(./scripts/load-dev-secrets.sh)
cd bootstrap/envs/dev
tofu init
tofu apply
```

------

## Delegating a Domain to Cloudflare

1. After having run the bootstrap apply step above, OpenTofu will output two Cloudflare **nameservers**.
2. In your domain registrar’s control panel:
   - Find the section for setting custom nameservers.
   - Replace the registrar’s default nameservers with the two from Cloudflare.

This step delegates control of DNS to Cloudflare.

---

## Next Steps

Part 2 will introduce:

- Ghost instance provisioning on Vultr
- DNS and TLS configuration
- Cloudflare R2-backed OpenTofu state
- Deeper network and access planning
