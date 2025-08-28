terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "~> 2.18"
    }
  }
}

resource "vultr_block_storage" "this" {
  region                = var.region
  size_gb               = var.size_gb
  label                 = var.label
  live                  = true
  attached_to_instance  = var.mount_instance_id
}