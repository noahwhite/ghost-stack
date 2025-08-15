# Secrets Management MVP / Dev-Only Stage

This project currently operates in a single-environment setup: **`dev` only**. As the infrastructure evolves, we'll adopt additional environments (staging, production), but this document describes the initial development workflow for the MVP phase.

## Goals of the MVP Secrets Management

- Secrets stored in **1Password GUI** (or your tool of choice), injected at runtime

---

## Secrets Management

### Vultr Secrets Management Strategy

Vultr does not currently offer a fine-grained API token system like Cloudflare. Instead, they use a single API key per account, which has full access to all account resources. To maintain good security hygiene and separation of concerns, this project applies the following best practices:

#### Best Practices

- **Environment Isolation**: Use separate Vultr accounts for each environment — `dev`, `staging`, and `production`. This prevents access to non-dev resources when working in the dev environment.
- **Secure Storage**: Store each environment’s API key in a password manager like 1Password and inject it into the environment only when needed via a prompting script.
- **Manual Injection**: Do not store API keys in plaintext or in version-controlled files. Use a prompt-based script to load keys into the environment securely.
- **Limited Exposure**: Only expose the API key to trusted processes or individuals working in that specific environment. Never use the same key across environments.
- **Key Rotation**: Periodically rotate Vultr API keys via the Vultr console and update the password manager and environment accordingly.
- **No Hardcoding**: Avoid embedding keys directly in Terraform or any configuration files.

#### Limitations Compared to Cloudflare

| Feature                          | Vultr Support                 |
| -------------------------------- | ----------------------------- |
| Scoped API Tokens                | ❌ No                          |
| Expiring Credentials             | ❌ No                          |
| Role-based Access Control (RBAC) | ❌ No                          |
| Per-environment Isolation        | ✔️ Yes (via separate accounts) |

This project uses 1 Vultr API key for the dev environment:

| Token Name              | Permissions    | Purpose                                     |
| ----------------------- | -------------- | ------------------------------------------- |
| `Personal Access Token` | `Account:Edit` | Used to manage all resources in the account |

While Vultr's lack of fine-grained token control means more reliance on strict account separation, the approach outlined above helps preserve security and maintainability within the scope of this project.

### Cloudflare Secrets Management Strategy

This project uses **one Cloudflare and Vultr account per environment** (dev, staging, production). This separation enforces a clear boundary between environments, helping to prevent mistakes such as:

- Deploying test code to production resources
- Limit blast radius for accidental changes
- Leaking production secrets during development
- Enforce strict permission boundaries via API token scoping
- Mixing metrics, logs, or infrastructure between environments

Isolating credentials and environments also enables least-privilege permissions and better auditability.

### Cloudflare Token Strategy for Bootstrapping

This project uses 2 separate Cloudflare API tokens for the dev bootstrap environment**:

| **Token Name**      | **Purpose**                                          | **Permissions (Summary)**                               | **Created With**                |
| ------------------- | ---------------------------------------------------- | ------------------------------------------------------- | ------------------------------- |
| dev-token-creator   | Token used to **create other scoped tokens**         | API Tokens:Edit on dev account                          | Manually via Cloudflare UI      |
| bootstrap-dev-token | Used to provision the R2 bucket for state & DNS zone | Zone:Edit, Zone:Read, DNS:Edit, R2 Storage Buckets:Edit | Created using dev-token-creator |

#### Manual Creation Instructions

***NOTE:*** The first time you log into the Cloudflare account dashboard, and until you complete the OpenTofu bootstrapping process which creates the DNS zone resource, you will be asked to enter an existing domain or register a new domain. **Do not do this** as we want to manage all infrastructure with IaC and creating it using the dashboard like this will be out-of-band of that IaC process.

1. **Create `dev-token-creator`** in the Cloudflare dashboard (dev account):
   - Go to **My Profile → API Tokens → Create Token**
   - Select the template: **"Create Additional Tokens"**
     - Permissions: Leave as "User", "API Tokens", "Edit"
     - **Apply additional security options (recommended):**
       - Set **Operator** to: equal
       - Enter your IP (e.g., 203.0.113.42)
     - **TTL (Time To Live) (recommended)**:
       - Set for 30 days
     - Click **Continue to Summary**, then **Create Token**
     - Save the token securely (e.g., in **1Password**) — it **will not be shown again**
2. Use opentofu/bootstrap/scripts/generate-bootstrap-token.sh to generate a token that will be able to create the bootstrap infra
3. The bootstrap token will be generated and automatically copied to your clipboard on MacOS. Paste it into 1Password (or your password manager of choice).


### Using The Secrets

Rather than using 1Password CLI or storing secrets in plain `.tfvars` files, we use a **copy-paste and prompt-based workflow**:

1. Secrets (like Cloudflare and Vultr credentials) are securely stored in 1Password GUI.

2. At runtime, you run the secrets loader script, which prompts for secrets one-by-one:

   ```bash
   ./scripts/env/load-dev-secrets.sh
   ```

3. The script exports the secrets to the environment so OpenTofu can access them.

This approach:

- Keeps secrets **out of version control**
- Avoids writing unencrypted secrets to disk
- Is easy to use and cross-platform
- Eliminates the need for extra tooling

### Required Secrets

| Name                         | Description                              |
| ---------------------------- | ---------------------------------------- |
| `VULTR_API_KEY`              | Vultr API Key for provisioning           |
| `CLOUDFLARE_BOOTSTRAP_TOKEN` | Scoped API token for Cloudflare R2 + DNS |
| `TOFU_CLOUDFLARE_ACCOUNT_ID` | Cloudflare Account ID (non-sensitive)    |

---

📁 _This document lives at `docs/secrets-management.md` in the repository._