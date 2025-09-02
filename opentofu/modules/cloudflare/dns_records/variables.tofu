variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare Zone ID to associate the Mailgun DNS records with."
}

variable "origin_ipv4" {
  type        = string
  description = "IP address of origin"
}