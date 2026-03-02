variable "vultr_api_key" {
  description = "Vultr API key for provider auth"
  type        = string
  sensitive   = true
}

variable "firewall_name" {
  description = "Name for the Vultr firewall group"
  type        = string
}

variable "admin_subnets" {
  description = "List of {subnet, subnet_size} objects allowed for SSH"
  type        = list(object({ subnet = string, subnet_size = number }))
  default     = []
}

# Instance inputs passed down to module "vm"
variable "instance_name" {
  description = "Hostname/label for the instance"
  type        = string
}

variable "instance_region" {
  description = "Vultr region slug (e.g., ewr, lax, fra)"
  type        = string
}

variable "instance_plan" {
  description = "Vultr plan slug (e.g., vc2-1c-1gb)"
  type        = string
}

variable "ssh_key_name" {
  description = "Name to register the SSH public key as in Vultr"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key material (ssh-ed25519 ...)"
  type        = string
  # public keys aren't secret; keep as plain string
}

variable "ghost_url" {
  description = "Canonical URL used by Ghost (dev)"
  type        = string
}

variable "locksmith_mask" {
  description = "Mask Flatcar auto-reboots in dev"
  type        = bool
  default     = true
}

variable "block_storage_size_gb" {
  description = "Size of the block storage volume in GB"
  type        = number
  default     = 25
}

variable "block_storage_label" {
  description = "Label for the block storage volume"
  type        = string
  default     = "ghost-block"
}

variable "PD_CLIENT_ID" {
  description = "Pagerduty OAUTH client id"
  type        = string
  sensitive   = true
}

variable "PD_CLIENT_SECRET" {
  description = "Pagerduty client secret"
  type        = string
  sensitive   = true
}

variable "pd_subdomain" {
  description = "Pagerduty subdomain"
  type        = string
}

variable "pd_user_tok" {
  description = "Pagerduty user token"
  type        = string
  sensitive   = true
}

variable "GC_ACCESS_TOK" {
  description = "Grafana Cloud access token"
  type        = string
  sensitive   = true
}

variable "SOC_DEV_TERRAFORM_SA_TOK" {
  description = "Grafana Cloud SOC DEV Service Account Token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID (optional, reads from bootstrap state if not provided)"
  type        = string
  default     = ""
}

# ==========================================================================
# Ghost Compose Configuration
# ==========================================================================

variable "ghost_domain" {
  description = "Ghost site domain"
  type        = string
  default     = "separationofconcerns.dev"
}

variable "ghost_admin_domain" {
  description = "Ghost admin panel domain"
  type        = string
  default     = "admin.separationofconcerns.dev"
}

variable "admin_ip" {
  description = "Admin workstation IP for Caddy access control (from Bitwarden)"
  type        = string
}

variable "mail_smtp_user" {
  description = "SMTP username for transactional email"
  type        = string
  default     = "postmaster@mg.separationofconcerns.dev"
}

variable "tinybird_api_url" {
  description = "Tinybird regional API endpoint"
  type        = string
  default     = "https://api.us-east.tinybird.co"
}

# ==========================================================================
# Infisical Provider (management identity credentials)
# ==========================================================================

variable "infisical_client_id" {
  description = "Infisical management identity client ID (used by OpenTofu to manage Infisical resources)"
  type        = string
  sensitive   = true
}

variable "infisical_client_secret" {
  description = "Infisical management identity client secret"
  type        = string
  sensitive   = true
}

variable "infisical_org_id" {
  description = "Infisical organization ID"
  type        = string
}

variable "tailscale_tailnet" {
  description = "Tailscale tailnet name"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID (used for R2 endpoint construction)"
  type        = string
}

variable "r2_dev_backups_bucket" {
  description = "R2 bucket name for nightly backups"
  type        = string
  default     = "ghost-backups-dev-separationofconcerns-dev"
}
