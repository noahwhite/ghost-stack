variable "cloudflare_zone_name" {
  type        = string
  description = "The name of the DNS zone to create in Cloudflare"
}

variable "cloudflare_account_id" {
  type        = string
  sensitive   = true
  description = "The Cloudflare account ID where the zone will be created"
}