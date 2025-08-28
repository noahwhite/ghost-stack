variable "name" {
  description = "Human-readable name/description for the firewall group"
  type        = string
}

# Example: [{ subnet = "203.0.113.5", subnet_size = 32 }]
variable "admin_subnets" {
  description = "List of admin subnets allowed for SSH as objects {subnet, subnet_size}"
  type        = list(object({ subnet = string, subnet_size = number }))
  default     = []
}
