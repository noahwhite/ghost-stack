terraform {
  required_providers {
    vultr = { source = "vultr/vultr", version = "= 2.22.1" }
    ct = {
      source  = "poseidon/ct"
      version = "0.13.0"
    }
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
  ghost_service_b64 = filebase64("${path.module}/userdata/ghost-compose.service")
  # stringify bool for the template condition (templatefile only supports strings)
  locksmith_mask = var.locksmith_mask ? "true" : "false"

  # ==========================================================================
  # Ghost Compose Configuration Files (Ephemeral via Ignition)
  # ==========================================================================
  # These files are deployed to /etc/ghost-compose/ at boot time.
  # Template files (.tftpl) are processed with templatefile() for variable interpolation.
  # Static files are read directly with file().

  # Template files - processed with OpenTofu variables
  ghost_compose_yml = base64encode(templatefile("${path.module}/userdata/ghost-compose/compose.yml.tftpl", {}))

  ghost_env_config = base64encode(templatefile("${path.module}/userdata/ghost-compose/env.config.tftpl", {
    ghost_domain       = var.ghost_domain
    ghost_admin_domain = var.ghost_admin_domain
    ghost_version      = var.ghost_version
    admin_ip           = var.admin_ip
    mail_smtp_host     = var.mail_smtp_host
    mail_smtp_user     = var.mail_smtp_user
  }))

  # Static files - no variable interpolation needed
  ghost_caddyfile               = filebase64("${path.module}/userdata/ghost-compose/caddy/Caddyfile")
  ghost_caddy_activitypub       = filebase64("${path.module}/userdata/ghost-compose/caddy/snippets/ActivityPub")
  ghost_caddy_logging           = filebase64("${path.module}/userdata/ghost-compose/caddy/snippets/Logging")
  ghost_caddy_security_headers  = filebase64("${path.module}/userdata/ghost-compose/caddy/snippets/SecurityHeaders")
  ghost_caddy_traffic_analytics = filebase64("${path.module}/userdata/ghost-compose/caddy/snippets/TrafficAnalytics")
  ghost_mysql_init              = filebase64("${path.module}/userdata/ghost-compose/mysql-init/create-multiple-databases.sh")

  # TinyBird Analytics provisioning
  ghost_tinybird_dockerfile = filebase64("${path.module}/userdata/ghost-compose/tinybird/Dockerfile")
  tinybird_provision_script = filebase64("${path.module}/userdata/tinybird-provision.sh")
}

# (The data source will fail if not exists; so we just create the resource unconditionally.)
resource "vultr_ssh_key" "this" {
  name    = var.ssh_key_name
  ssh_key = var.ssh_public_key
}

data "ct_config" "ghost" {
  content = templatefile("${path.module}/userdata/ghost.bu", {
    ghost_service     = local.ghost_service_b64,
    locksmith_mask    = local.locksmith_mask,
    tailscale_authkey = var.tailscale_authkey

    # Ghost Compose configuration files (ephemeral)
    ghost_compose_yml             = local.ghost_compose_yml
    ghost_env_config              = local.ghost_env_config
    ghost_caddyfile               = local.ghost_caddyfile
    ghost_caddy_activitypub       = local.ghost_caddy_activitypub
    ghost_caddy_logging           = local.ghost_caddy_logging
    ghost_caddy_security_headers  = local.ghost_caddy_security_headers
    ghost_caddy_traffic_analytics = local.ghost_caddy_traffic_analytics
    ghost_mysql_init              = local.ghost_mysql_init

    # TinyBird Analytics provisioning
    ghost_tinybird_dockerfile = local.ghost_tinybird_dockerfile
    tinybird_provision_script = local.tinybird_provision_script
  })
  strict = true
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

  user_data = data.ct_config.ghost.rendered

  # Optional niceties
  backups          = "disabled"
  ddos_protection  = false
  activation_email = false
  tags             = ["ghost"]
}