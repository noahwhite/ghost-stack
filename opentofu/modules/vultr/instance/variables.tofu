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