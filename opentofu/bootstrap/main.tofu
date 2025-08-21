terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }

  backend "local" {}
}

provider "cloudflare" {
  email = "noah@separationofconcerns.dev"
}

module "state_bucket" {
  source                = "./modules/r2"
  cloudflare_account_id = var.cloudflare_account_id
  r2_bucket_name        = var.r2_bucket_name
}

module "dns_zone" {
  source                = "./modules/cloudflare_zone"
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_zone_name  = var.cloudflare_zone_name
}

module "email_routing" {
  source                = "./modules/email_routing"
  cloudflare_zone_id    = module.dns_zone.zone_id
  cloudflare_account_id = var.cloudflare_account_id
  source_email          = var.source_email
  destination_email     = var.destination_email
}