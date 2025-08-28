output "id" {
  value       = vultr_block_storage.this.id
  description = "The ID of the block storage volume"
}

output "region" {
  value       = vultr_block_storage.this.region
  description = "The region of the volume"
}

output "label" {
  value       = vultr_block_storage.this.label
  description = "The volume label"
}

output "mount_id" {
  value       = vultr_block_storage.this.mount_id
  description = "Instance the volume is attached to (if any)"
}