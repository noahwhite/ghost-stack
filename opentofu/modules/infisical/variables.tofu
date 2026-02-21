variable "org_id" {
  description = "Infisical organization ID"
  type        = string
}

variable "environment" {
  description = "Environment slug to scope secrets and identity privileges to"
  type        = string
  default     = "dev"
}

variable "admin_email" {
  description = "Email of the human admin user to add as project administrator"
  type        = string
}

variable "instance_replacement_hash" {
  type        = string
  description = "Hash of all inputs that would cause instance replacement, triggering boot token regeneration"
  default     = ""
}
