output "instance_id" {
  value       = vultr_instance.this.id
  description = "Vultr instance ID"
}

output "main_ip" {
  value       = vultr_instance.this.main_ip
  description = "Primary IPv4 address"
}

output "ghost_ignition" {
  value = data.ct_config.ghost.pretty_print
}