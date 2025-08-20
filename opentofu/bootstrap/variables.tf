variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API token with R2 and DNS permissions"
}

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
