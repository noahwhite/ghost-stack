variable "vultr_api_key" {
  description = "Vultr API key for provider auth"
  type        = string
  sensitive   = true
}

variable "firewall_name" { type = string }

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