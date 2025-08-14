# R2 Bootstrap Stage (Terraform)

This folder provisions the Cloudflare R2 bucket used for storing the OpenTofu state file.

## Why use Terraform for this?

This approach is **declarative**, not imperative, and consistent with how the rest of the stack is managed.

## How to Use

```bash
export CLOUDFLARE_API_TOKEN=...
export CLOUDFLARE_ACCOUNT_ID=...
cd bootstrap_r2
tofu init
tofu apply
```
