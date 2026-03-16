terraform {
  # chore: retrigger deployment 2026-03-16
  backend "s3" {}
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "= 2.28.1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5"
    }
    ct = {
      source  = "poseidon/ct"
      version = "0.14.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.28.0"
    }
    pagerduty = {
      source  = "pagerduty/pagerduty"
      version = "~> 3.31.0" # Mind the supported Provider version
    }
    grafana = {
      source  = "grafana/grafana"
      version = "~> 4.28.0"
    }
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.16"
    }
  }
}

provider "vultr" {
  api_key = var.vultr_api_key
}

provider "cloudflare" {
  email = "noah@separationofconcerns.dev"
}

provider "ct" {}

provider "tailscale" {
  # Credentials are read from TAILSCALE_API_KEY environment variable in CI.
  # The empty block is required so mock_provider can intercept it during tofu test.
}

provider "pagerduty" {
  # Configure use of App Oauth scoped token
  use_app_oauth_scoped_token {
    pd_client_id     = var.PD_CLIENT_ID
    pd_client_secret = var.PD_CLIENT_SECRET
    pd_subdomain     = var.pd_subdomain
  }

  user_token = var.pd_user_tok
}

provider "grafana" {
  alias                     = "cloud"
  cloud_access_policy_token = var.GC_ACCESS_TOK
}

provider "infisical" {
  auth = {
    universal = {
      client_id     = var.infisical_client_id
      client_secret = var.infisical_client_secret
    }
  }
}

data "terraform_remote_state" "bootstrap" {
  count   = var.cloudflare_zone_id == "" ? 1 : 0
  backend = "local"

  # TODO: Parameterize the env when we have staging and prod envs so we find the right bootstrap state for the env
  #  we are working in
  config = {
    path = "${path.module}/../../bootstrap/envs/dev/terraform.tfstate"
  }
}

locals {
  # Use variable if provided (CI mode), otherwise read from bootstrap state (workstation mode)
  cloudflare_zone_id = var.cloudflare_zone_id != "" ? var.cloudflare_zone_id : data.terraform_remote_state.bootstrap[0].outputs.cloudflare_zone_id

  # ==========================================================================
  # Drift Recovery Note
  # ==========================================================================
  # If you need to retrigger a deployment to recover from drift (e.g., after
  # manually deleting an instance from Vultr), you must open a PR that touches
  # an infra file so that pr-tofu-plan-develop.yml generates a plan artifact.
  # A trivial comment change to this file is sufficient. Pushing a bare commit
  # directly to develop will NOT work — deploy-dev.yml requires a PR-backed
  # plan artifact.
  # See: docs/runbooks/retrigger-deployment.md
  # Last drift recovery: 2026-03-03 (Infisical boot token consumed before deploy)
  # ==========================================================================

  # ==========================================================================
  # Instance Replacement Hash
  # ==========================================================================
  # This hash captures all inputs that would cause the Vultr instance to be
  # replaced. When any of these change, the Tailscale auth key is also
  # regenerated to ensure the new instance can authenticate.
  #
  # Includes:
  # - Instance attributes (region, plan, name, firewall, ssh key)
  # - Userdata variables (domains, IPs, config values)
  # - Template/config files that compose the Ignition userdata
  instance_replacement_hash = sha256(jsonencode({
    # Instance attributes that force replacement
    region            = var.instance_region
    plan              = var.instance_plan
    name              = var.instance_name
    firewall_group_id = module.fw.id
    ssh_key_name      = var.ssh_key_name
    ssh_public_key    = var.ssh_public_key

    # Userdata variables
    ghost_url          = var.ghost_url
    ghost_domain       = var.ghost_domain
    ghost_admin_domain = var.ghost_admin_domain
    admin_ip           = var.admin_ip
    mail_smtp_user     = var.mail_smtp_user
    locksmith_mask     = var.locksmith_mask
    tinybird_api_url   = var.tinybird_api_url
    tailscale_tailnet  = var.tailscale_tailnet

    cloudflare_account_id = var.cloudflare_account_id
    r2_dev_backups_bucket = var.r2_dev_backups_bucket

    # Template and config file hashes (changes to these rebuild userdata)
    files = {
      ghost_bu                = filesha256("${path.module}/../../modules/vultr/instance/userdata/ghost.bu")
      ghost_compose_service   = filesha256("${path.module}/../../modules/vultr/instance/userdata/ghost-compose.service")
      tinybird_provision      = filesha256("${path.module}/../../modules/vultr/instance/userdata/tinybird-provision.sh")
      compose_yml             = filesha256("${path.module}/../../modules/vultr/instance/userdata/ghost-compose/compose.yml.tftpl")
      env_config              = filesha256("${path.module}/../../modules/vultr/instance/userdata/ghost-compose/env.config.tftpl")
      caddyfile               = filesha256("${path.module}/../../modules/vultr/instance/userdata/ghost-compose/caddy/Caddyfile")
      caddy_activitypub       = filesha256("${path.module}/../../modules/vultr/instance/userdata/ghost-compose/caddy/snippets/ActivityPub")
      caddy_logging           = filesha256("${path.module}/../../modules/vultr/instance/userdata/ghost-compose/caddy/snippets/Logging")
      caddy_security          = filesha256("${path.module}/../../modules/vultr/instance/userdata/ghost-compose/caddy/snippets/SecurityHeaders")
      caddy_analytics         = filesha256("${path.module}/../../modules/vultr/instance/userdata/ghost-compose/caddy/snippets/TrafficAnalytics")
      mysql_init              = filesha256("${path.module}/../../modules/vultr/instance/userdata/ghost-compose/mysql-init/create-multiple-databases.sh")
      tinybird_dockerfile     = filesha256("${path.module}/../../modules/vultr/instance/userdata/ghost-compose/tinybird/Dockerfile")
      infisical_secrets_fetch = filesha256("${path.module}/../../modules/vultr/instance/userdata/infisical-secrets-fetch.sh")
      monitor_tailscale       = filesha256("${path.module}/../../modules/vultr/instance/userdata/monitor_tailscale_conn.sh")
      ghost_entrypoint        = filesha256("${path.module}/../../modules/vultr/instance/userdata/ghost-entrypoint.sh")
      caddy_entrypoint        = filesha256("${path.module}/../../modules/vultr/instance/userdata/caddy-entrypoint.sh")
      activitypub_entrypoint  = filesha256("${path.module}/../../modules/vultr/instance/userdata/ghost-compose/activitypub-entrypoint.sh")
      ghost_backup            = filesha256("${path.module}/../../modules/vultr/instance/userdata/ghost-backup.sh")
      ghost_restore           = filesha256("${path.module}/../../modules/vultr/instance/userdata/ghost-restore.sh")
      ghost_retention         = filesha256("${path.module}/../../modules/vultr/instance/userdata/ghost-retention.sh")
    }
  }))
}

module "grafana-cloud" {
  source = "../../modules/grafana-cloud"
  providers = {
    grafana = grafana.cloud
  }
  pagerduty_backup_integration_key = module.pagerduty.backup_integration_key
  SOC_DEV_TERRAFORM_SA_TOK         = var.SOC_DEV_TERRAFORM_SA_TOK
}

module "pagerduty" {
  source = "../../modules/pagerduty"
}

module "tailscale" {
  source = "../../modules/tailscale"

  # Trigger auth key regeneration when instance will be replaced
  # This ensures a fresh one-time key is created when the instance is recreated
  instance_replacement_hash = local.instance_replacement_hash
}

module "dns_records" {
  source             = "../../modules/cloudflare/dns_records"
  cloudflare_zone_id = local.cloudflare_zone_id
  origin_ipv4        = module.vm.main_ip
}

module "fw" {
  source        = "../../modules/vultr/firewall"
  name          = var.firewall_name
  admin_subnets = var.admin_subnets
}

output "firewall_id" {
  value       = module.fw.id
  description = "Vultr firewall group ID"
}

module "vm" {
  source            = "../../modules/vultr/instance"
  name              = var.instance_name
  region            = var.instance_region
  plan              = var.instance_plan
  ssh_key_name      = var.ssh_key_name
  ssh_public_key    = var.ssh_public_key
  firewall_group_id = module.fw.id
  ghost_url         = var.ghost_url
  locksmith_mask    = var.locksmith_mask
  tailscale_authkey = module.tailscale.tailscale_auth_key

  # Ghost Compose configuration (non-secret)
  ghost_domain       = var.ghost_domain
  ghost_admin_domain = var.ghost_admin_domain
  admin_ip           = var.admin_ip
  mail_smtp_user     = var.mail_smtp_user
  tinybird_api_url   = var.tinybird_api_url
  tailscale_tailnet  = var.tailscale_tailnet

  infisical_boot_token  = terraform_data.boot_token_snapshot.output
  infisical_project_id  = module.infisical.project_id
  infisical_environment = "dev"

  # Backup (GHO-63)
  cloudflare_account_id = var.cloudflare_account_id
  r2_dev_backups_bucket = var.r2_dev_backups_bucket
}

module "block_storage" {
  source = "../../modules/vultr/block_storage"

  region            = var.instance_region
  size_gb           = var.block_storage_size_gb
  label             = var.block_storage_label
  mount_instance_id = module.vm.instance_id
}

module "infisical" {
  source = "../../modules/infisical"

  org_id                    = var.infisical_org_id
  environment               = "dev"
  admin_email               = "noah@noahwhite.net"
  instance_replacement_hash = local.instance_replacement_hash
}

# ==========================================================================
# Boot Token Stable Snapshot (GHO-85)
# ==========================================================================
# Decouples the Infisical boot token lifecycle (15-min TTL, single-use —
# Infisical deletes the record after consumption) from user_data.
#
# Without this, every plan run after first boot detects the deleted token,
# recreates it with a new value, and propagates that new value into user_data
# (ForceNew=true on Vultr instances), triggering an unintended instance rebuild
# and — critically — rebuilding the instance with the already-consumed Tailscale
# auth key, breaking Tailscale authentication.
#
# This resource captures the token value at instance creation time and holds it
# stable. It is only replaced when instance_replacement_hash changes (i.e., when
# the instance is genuinely being replaced), at which point a fresh token is
# captured for the new instance.
resource "terraform_data" "boot_token_snapshot" {
  input            = module.infisical.ghost_dev_boot_token
  triggers_replace = local.instance_replacement_hash

  lifecycle {
    # Suppress propagation of token value changes between instance replacements.
    # After first boot, Infisical deletes the consumed token and OpenTofu recreates
    # it with a new value. ignore_changes prevents that new value from reaching
    # user_data and causing an unintended rebuild.
    ignore_changes = [input]
  }
}
