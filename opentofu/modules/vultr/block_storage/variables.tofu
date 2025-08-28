###############################################
# modules/vultr_block_storage/variables.tf
###############################################

variable "region" {
  description = "Region slug for the Vultr volume (must match instance region)"
  type        = string
}

variable "size_gb" {
  description = "Size of the block storage volume in GB"
  type        = number
  default     = 25
}

variable "label" {
  description = "Label for the block storage volume"
  type        = string
  default     = "ghost-block"
}

variable "mount_instance_id" {
  description = "Optional instance ID to attach the volume to"
  type        = string
  default     = null
}