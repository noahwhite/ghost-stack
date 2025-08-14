locals {
  hostname = var.cloudflare_hostname
}

data "template_file" "cloud_init" {
  template = file("${path.module}/../../modules/ghost-vm/cloud-init.yml.tpl")
}

module "ghost_vm" {
  source     = "../../modules/vultr/vm"
  region     = var.vultr_region
  plan       = var.vultr_plan
  hostname   = local.hostname
  ssh_key_id = var.ssh_key_id
  user_data  = data.template_file.cloud_init.rendered
}

module "dns" {
  source    = "../../modules/cloudflare/dns"
  zone_name = var.cloudflare_zone_name
  hostname  = var.cloudflare_hostname
  target_ip = module.ghost_vm.public_ip
}

output "ghost_ip" {
  value = module.ghost_vm.public_ip
}
