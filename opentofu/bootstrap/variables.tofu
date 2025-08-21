variable "cloudflare_account_id" {
  type        = string
  sensitive   = true
  description = "Your Cloudflare account ID"
}

variable "cloudflare_zone_name" {
  type        = string
  description = "Zone name for your Cloudflare DNS (e.g., separationofconcerns.dev)"
}

variable "r2_bucket_name" {
  type        = string
  description = "Name of the R2 bucket used for OpenTofu state storage"
}

variable "source_email" {
  description = "The custom domain email address to forward"
  type        = string
  sensitive   = true
}

variable "destination_email" {
  description = "The target email address to forward to"
  type        = string
  sensitive   = true
}