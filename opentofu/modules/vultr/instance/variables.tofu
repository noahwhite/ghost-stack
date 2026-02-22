variable "name" {
  description = "Hostname/label for the instance"
  type        = string
}

variable "region" {
  description = "Vultr region slug (e.g., ewr, lax, fra, sgp)"
  type        = string
}

variable "plan" {
  description = "Vultr plan slug (e.g., vc2-1c-1gb, vc2-1c-2gb)"
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the SSH key in Vultr (will create if not found)"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key material (e.g., ssh-ed25519 AAAA...)"
  type        = string
}

variable "firewall_group_id" {
  description = "Vultr firewall group ID to attach"
  type        = string
}

variable "user_data" {
  description = "Cloud-init style user data to bootstrap Docker + Ghost"
  type        = string
  default     = ""
}

# URL Ghost should use (dev: http://separationofconverns.dev or http://<ip>)
variable "ghost_url" {
  description = "Canonical URL Ghost should use"
  type        = string
}

# In dev, we usually mask auto-reboots; in prod you can set this to false
variable "locksmith_mask" {
  description = "Mask Flatcar locksmithd (auto-reboots). true for dev"
  type        = bool
  default     = true
}

variable "tailscale_authkey" {
  type      = string
  sensitive = true
}

# ==========================================================================
# Ghost Compose Configuration (Non-Secret)
# ==========================================================================
# These variables are used to generate the ephemeral .env.config file
# that is deployed via Ignition. Secrets are managed separately in
# /var/mnt/storage/ghost-compose/.env.secrets on block storage.

variable "ghost_domain" {
  description = "Ghost site domain (e.g., separationofconcerns.dev)"
  type        = string
}

variable "ghost_admin_domain" {
  description = "Ghost admin panel domain (e.g., admin.separationofconcerns.dev)"
  type        = string
}

variable "ghost_version" {
  description = "Ghost Docker image tag"
  type        = string
  default     = "6-alpine"
}

variable "admin_ip" {
  description = "Admin workstation IP for Caddy access control"
  type        = string
}

variable "mail_smtp_host" {
  description = "SMTP host for transactional email"
  type        = string
  default     = "smtp.mailgun.org"
}

variable "mail_smtp_user" {
  description = "SMTP username for transactional email"
  type        = string
}

variable "tinybird_api_url" {
  description = "Tinybird regional API endpoint (e.g., https://api.us-east.tinybird.co)"
  type        = string
  default     = "https://api.tinybird.co"
}

variable "infisical_boot_token" {
  description = "Single-use Infisical access token for boot-time secret fetching via Token Auth"
  type        = string
  sensitive   = true
}

variable "infisical_project_id" {
  description = "Infisical project ID for boot-time secrets fetch"
  type        = string
}

variable "infisical_environment" {
  description = "Infisical environment slug for boot-time secrets fetch (e.g., dev)"
  type        = string
}

variable "tailscale_tailnet" {
  description = "Tailscale tailnet name for device status monitoring (e.g., example.com)"
  type        = string
}