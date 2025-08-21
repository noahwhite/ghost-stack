output "public_ip" {
  value = vultr_instance.ghost.main_ip
}
output "instance_id" {
  value = vultr_instance.ghost.id
}
