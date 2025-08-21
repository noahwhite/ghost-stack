
# Bootstrap Infrastructure

This directory contains one-time infrastructure code that bootstraps the OpenTofu environment for the `dev` environment. It provisions foundational cloud resources **before** the main stack can be deployed.

---

## What This Bootstrap Code Provisions

- A Cloudflare **R2 bucket** for OpenTofu state storage (with **versioning enabled**)
- A Cloudflare **DNS zone** for `separationofconcerns.dev`

These are required to enable remote state locking and DNS delegation in the MVP deployment phase.

---

## 📁 Directory Structure

```
bootstrap/
├── README.md
├── main.tf
├── outputs.tf
├── variables.tf
├── envs/
│   └── dev/
│       └── dev.tfvars
├── modules/
│   ├── cloudflare_zone/
│   │   ├── main.tf
|		|		├── outputs.tf
│   │   └── variables.tf
│   ├── email_routing/
│   │   ├── main.tf
|		|		├── outputs.tf
│   │   └── variables.tf
│   └── r2/
│       ├── README.md
│       ├── main.tf
│       └── variables.tf
├── scripts/
│   ├── bootstrap-dev.sh
│   ├── generate-bootstrap-token.sh
│   ├── list-permission-groups.sh
│   └── set-cloudflare-env.sh
```

---

## Bootstrapping Instructions

### Step 0: Manually Create the Token Used to Bootstrap API Tokens And Obtain Cloudflare Account ID

Before starting, you must create a Cloudflare API token with permission to generate other tokens. This is referred to as the **dev-token-creator**.

Follow the instructions in [`docs/secrets-management.md`](../../docs/secrets-management.md#manual-creation-instructions) to:

- Create this token with the `User: API Tokens - Edit` permission
- Store it securely (e.g., in 1Password)
- Paste it into the prompt when running the bootstrap token generator script in Step 1

You will also need your Cloudflare Account ID. The easiest way to obtain it is to simply copy it from the Cloudflare dashboard URL after you have created the bootstrap API token. The account ID is the long string of characters in the URL directly between dash.cloudflare.com/ and /api-tokens. For example:

https://dash.cloudflare.com/<CLOUDFLARE ACCOUNT ID>/api-tokens

- Store it securely (e.g., in 1Password)
- Paste it into the prompt when running the bootstrap token generator script in Step 1

### Step 1: Enable R2 In Your Cloudflare Account

Before you are able to use R2 you must first enable billing on it. 

1. In your Cloudflare dashboard click on R2 Object Storage and enter your credit card billing details 
2. Once you see the R2 Object Storage Overview screen proceed to the next step

### Step 2: Generate a Cloudflare R2 + DNS API Token

Once you have your bootstrap token, you can use it to generate a Cloudflare API token with the correct scopes:

```bash
./opentofu/bootstrap/scripts/generate-cloudflare-token.sh
```

This will securely prompt you for your Cloudflare Account ID and Bootstrap Token, generate a signed JWT with R2 + DNS scopes, and copy it to your clipboard. Paste it into your secrets manager (e.g., 1Password).

### Step 3: Export Secrets in Your Host Shell & Launch Docker Shell with Secrets Injected

```bash
./docker/scripts/infra-shell.sh
```

This script:
- Securely prompts for secrets and other sensitive information
- Validates the presence of required environment variables
- Passes them securely to the container with `--env`
- Suppresses shell history inside the container

### Step 4: Initialize and Apply the Bootstrap Stack

Still within the Docker shell, run:

```bash
opentofu/bootstrap/scripts/bootstrap-dev.sh
```

This will:
- Initialize the OpenTofu backend
- Plan the dev environment
- Apply the changes to provision R2, DNS, and E-Mail routing resources
- Create a .terraform.lock.hcl file which is used to pin the providers. You should add this to your git repo. 

You should see the changes which OpenTofu will apply to your Cloudflare resources. They will consist of a new zone as well as an R2 bucket to store Terraform state. 

You will be prompted to confirm these changes by typing, "yes". After you do this OpenTofu will apply them and output a list of name servers which you will need to delegate the domain to. For example:

```module.state_bucket.cloudflare_r2_bucket.state: Refreshing state... [id=ghost-stack-dev-state]
module.dns_zone.cloudflare_zone.main: Refreshing state... [id=102d0aca79d2160eb547c6fe3ccf3444]

Outputs:

cloudflare_nameservers = tolist([
  "dolly.ns.cloudflare.com",
  "ganz.ns.cloudflare.com",
])
r2_bucket_name = "ghost-stack-dev-state"
```

### Step 5: Delegate DNS to Cloudflare

Using the name servers output by Cloudflare you should go to your dev domain's registrar and delegate DNS to Cloudflare. It will take a few hours for this to propagate to name servers around the globe. You can check the progress at: https://www.whatsmydns.net/#NS/separationofconcerns.dev 

---

## Notes

- You only need to bootstrap **once per environment**.
- Future runs of the main stack depend on the state bucket and DNS zone this process creates.
- Store your bootstrap token and generated Cloudflare token in a secure secrets manager.

---

## DO NOT DESTROY THE BOOTSTRAP STACK

Destroying the bootstrap stack will:
- Permanently delete the R2 bucket containing OpenTofu state
- Remove the Cloudflare DNS zone that manages your domain

This would render your infrastructure **unusable**.

➡️ **Never run `opentofu destroy` on the bootstrap stack unless you are intentionally decommissioning the entire system.**

---

## Security Practices

- No sensitive values are stored in Git.
- Dockerized environment keeps host machine clean.
- Bootstrap token is single-purpose and time-limited.
- Shell history is disabled in `infra-shell.sh` for sensitive command protection.
- Secrets are securely injected using `--env`, which is compatible with CI/CD pipelines.

---

Ready to deploy the main infrastructure stack? Head over to `opentofu/main/` once bootstrap is complete.
