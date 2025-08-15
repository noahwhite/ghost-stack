> This repository contains the infrastructure-as-code implementation for [**Ghost in the Stack**](https://www.noahwhite.net/soc/ghost-in-the-stack), a blog series exploring real-world DevOps practices from first principles. It documents the full lifecycle of self-hosting a Ghost blog — beginning with a lightweight MVP on Vultr and evolving into a resilient, cloud-native platform.


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


## Workflow Documentation

For a detailed explanation of the Git workflow in the current **MVP/dev-only** environment, see:

➡️ [`docs/git-workflow-mvp.md`](docs/git-workflow-mvp.md)

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

Secrets management is documented here: [`Secrets Management`](docs/secrets-management.md)

---

## Obtain A Domain For The Development Environment

1. Purchase a domain name (e.g., from Porkbun) for the dev environment. We picked **separationofconcerns.dev**
2. Continue with the bootstrap process

------

## Bootstrap Infrastructure

Before delegating the domain and running the main infrastructure, you must do a one time provisioning of R2 and DNS which is documented here: [`Bootstrap README`](opentofu/bootstrap/README.md)

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
