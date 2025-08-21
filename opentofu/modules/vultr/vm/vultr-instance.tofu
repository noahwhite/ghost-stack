resource "vultr_instance" "ghost" {
  region     = var.region
  plan       = var.plan
  os_id      = 1743 # Ubuntu 22.04 x64
  hostname   = var.hostname
  label      = var.hostname
  ssh_key_ids = var.ssh_key_id != "" ? [var.ssh_key_id] : []
  user_data  = var.user_data
}
