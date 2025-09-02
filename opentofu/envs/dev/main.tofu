terraform {
  backend "s3" {}
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.20"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
    ct = {
        source  = "poseidon/ct"
        version = "0.13.0"
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

data "terraform_remote_state" "bootstrap" {
  backend = "local"

  # TODO: Parameterize the env when we have staging and prod envs so we find the right bootstrap state for the env
  #  we are working in
  config = {
    path = "${path.module}/../../bootstrap/envs/dev/terraform.tfstate"
  }
}

module "dns_records" {
  source              = "../../modules/cloudflare/dns_records"
  cloudflare_zone_id  = data.terraform_remote_state.bootstrap.outputs.cloudflare_zone_id
  origin_ipv4         = module.vm.main_ip
}

module "fw" {
  source                  = "../../modules/vultr/firewall"
  name                    = var.firewall_name
  admin_subnets           = var.admin_subnets
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
}

module "block_storage" {
  source = "../../modules/vultr/block_storage"

  region             = var.instance_region
  size_gb            = var.block_storage_size_gb
  label              = var.block_storage_label
  mount_instance_id  = module.vm.instance_id
}
