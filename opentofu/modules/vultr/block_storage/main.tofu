terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "= 2.28.1"
    }
  }
}

resource "vultr_block_storage" "this" {
  region               = var.region
  size_gb              = var.size_gb
  label                = var.label
  live                 = true
  attached_to_instance = var.mount_instance_id
}
