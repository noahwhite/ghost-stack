variable "cloudflare_zone_id" {
  description = "Zone ID of the domain to configure email routing for"
  type        = string
}

variable "cloudflare_account_id" {
  type        = string
  sensitive   = true
  description = "Your Cloudflare account ID"
}

variable "source_email" {
  description = "The custom domain email address to forward"
  sensitive   = true
  type        = string
}

variable "destination_email" {
  description = "The target email address to forward to"
  sensitive   = true
  type        = string
}
