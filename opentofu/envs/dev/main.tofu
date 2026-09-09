terraform {
  # chore: retrigger deployment 2026-03-29
  backend "s3" {}
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5"
    }
    pagerduty = {
      source  = "pagerduty/pagerduty"
      version = "~> 3.35.0" # Mind the supported Provider version
    }
    grafana = {
      source  = "grafana/grafana"
      version = "~> 4.46.0"
    }
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.19"
    }
  }
}

provider "cloudflare" {
  email = "noah@separationofconcerns.dev"
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

module "dns_records" {
  source             = "../../modules/cloudflare/dns_records"
  cloudflare_zone_id = local.cloudflare_zone_id
}

module "infisical" {
  source = "../../modules/infisical"

  org_id      = var.infisical_org_id
  environment = "dev"
  admin_email = "noah@noahwhite.net"

}
