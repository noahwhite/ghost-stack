# Bootstrap Infrastructure

This directory contains one-time infrastructure code that bootstraps the OpenTofu environment for the `dev` environment. It is responsible for provisioning foundational resources that are required **before** the main infrastructure can be deployed.

## What Does This Bootstrap Do?

It provisions:

- A Cloudflare **R2 bucket** for OpenTofu state storage
- A Cloudflare **DNS zone** for the `separationofconcerns.dev` domain

These resources are essential to enable remote state management and DNS delegation during the MVP deployment phase.

## Structure

```
bootstrap/
├── README.md
├── envs/
│   ├── dev/
│   │   ├── cloudflare_zone.tf
│   │   ├── r2.tf
├── modules/
│   ├── cloudflare_zone/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   ├── r2/
│   │   ├── README.md
│   │   ├── main.tf
│   │   ├── variables.tf
```

## How to Bootstrap

### Step 1: Set Required Environment Variables

To avoid writing sensitive values into your `.tfvars` files, export the required variables before initializing and applying OpenTofu:

```bash
export TF_VAR_r2_account_id="your-cloudflare-account-id"
export TF_VAR_r2_access_key_id="your-access-key"
export TF_VAR_r2_secret_access_key="your-secret-key"
export TF_VAR_cloudflare_api_token="your-cloudflare-api-token"
export TF_VAR_domain_name="separationofconcerns.dev"
```

### Step 2: Initialize OpenTofu

```bash
cd opentofu/bootstrap/envs/dev
tofu init
```

### Step 3: Apply the Bootstrap

```bash
tofu apply
```

### Step 4: Update Your Domain Registrar (Porkbun)

After the Cloudflare zone is created, OpenTofu will output the Cloudflare nameservers.

Use these to update the nameservers in your domain registrar (e.g., Porkbun) so DNS resolution is handled by Cloudflare.

## Cleanup

The state file for this bootstrap run will be stored locally by default (`terraform.tfstate` in this directory).

You may migrate it into your R2 backend later, but this is not required for a one-time bootstrap process.