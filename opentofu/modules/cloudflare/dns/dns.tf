terraform {
  required_providers {
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 4.0" }
  }
}

variable "zone_name" { type = string }
variable "hostname"  { type = string }
variable "target_ip" { type = string }

data "cloudflare_zones" "target" {
  filter {
    name   = var.zone_name
    status = "active"
    paused = false
  }
}

resource "cloudflare_record" "a" {
  zone_id = data.cloudflare_zones.target.zones[0].id
  name    = var.hostname
  type    = "A"
  value   = var.target_ip
  proxied = true
  ttl     = 300
}
