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
