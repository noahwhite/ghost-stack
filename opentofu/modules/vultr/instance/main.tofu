terraform {
  required_providers {
    vultr = { source = "vultr/vultr", version = "~> 2.27" }
  }
}

# Flatcar lookup
data "vultr_os" "flatcar" {
  filter {
    name   = "name"
    values = ["Flatcar Container Linux Stable x64"] # exact match required
  }
}

locals {
  ghost_env     = <<-EOT
url=${var.ghost_url}
database__client=sqlite3
database__connection__filename=/var/lib/ghost/content/data/ghost.db
EOT
  ghost_env_b64 = base64encode(local.ghost_env)
  ghost_service_b64 = filebase64("${path.module}/userdata/ghost.service")
  # stringify bool for the template condition (templatefile only supports strings)
  locksmith_mask     = var.locksmith_mask ? "true" : "false"
}

# (The data source will fail if not exists; so we just create the resource unconditionally.)
resource "vultr_ssh_key" "this" {
  name    = var.ssh_key_name
  ssh_key = var.ssh_public_key
}

resource "vultr_instance" "this" {
  region            = var.region
  plan              = var.plan
  os_id             = data.vultr_os.flatcar.id
  label             = var.name
  hostname          = var.name
  enable_ipv6       = false
  firewall_group_id = var.firewall_group_id
  ssh_key_ids       = [vultr_ssh_key.this.id]

  # Cloud-init user-data to install Docker and run Ghost
  user_data         = templatefile("${path.module}/userdata/ghost.ign.tpl", {
    ghost_env     = local.ghost_env_b64
    ghost_service = local.ghost_service_b64
    locksmith_mask    = local.locksmith_mask
  })

  # Optional niceties
  backups           = "disabled"
  ddos_protection   = false
  activation_email  = false
  tags              = ["ghost"]
}