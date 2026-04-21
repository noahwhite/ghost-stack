terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "= 2.30.1"
    }
  }
}

# List of Cloudflare IPv4 ranges (as of 2025-09)
locals {
  cloudflare_ipv4_ranges = [
    "173.245.48.0/20",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "141.101.64.0/18",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
    "162.158.0.0/15",
    "104.16.0.0/13",
    "104.24.0.0/14",
    "172.64.0.0/13",
    "131.0.72.0/22",
  ]
}

resource "vultr_firewall_group" "this" {
  description = var.name
}


# ----------------
# IPv4 rules
# ----------------

# HTTP/HTTPS from anywhere
resource "vultr_firewall_rule" "http" {
  for_each          = { for i, s in var.admin_subnets : i => s }
  firewall_group_id = vultr_firewall_group.this.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = each.value.subnet
  subnet_size       = each.value.subnet_size
  port              = "80"
  notes             = "HTTP"
}

resource "vultr_firewall_rule" "https" {
  for_each          = { for i, s in var.admin_subnets : i => s }
  firewall_group_id = vultr_firewall_group.this.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = each.value.subnet
  subnet_size       = each.value.subnet_size
  port              = "443"
  notes             = "HTTPS"
}

# Allow TCP/443 (HTTPS) from Cloudflare edge IPs
resource "vultr_firewall_rule" "allow_https_from_cloudflare" {
  for_each = toset(local.cloudflare_ipv4_ranges)

  firewall_group_id = vultr_firewall_group.this.id
  ip_type           = "v4"
  protocol          = "tcp"
  port              = "443"
  subnet            = cidrhost(each.key, 0)
  subnet_size       = tonumber(split("/", each.key)[1])
  notes             = "Allow HTTPS from Cloudflare ${each.key}"
}