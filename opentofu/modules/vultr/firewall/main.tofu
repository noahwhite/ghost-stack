terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.27"
    }
  }
}

resource "vultr_firewall_group" "this" {
  description = var.name
}


# ----------------
# IPv4 rules
# ----------------

# SSH from admin subnets
resource "vultr_firewall_rule" "ssh_admin" {
  for_each          = { for i, s in var.admin_subnets : i => s }
  firewall_group_id = vultr_firewall_group.this.id
  protocol          = "tcp"
  ip_type           = "v4"
  subnet            = each.value.subnet
  subnet_size       = each.value.subnet_size
  port              = "22"
  notes             = "SSH (admin subnet)"
}

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