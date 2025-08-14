variable "vultr_api_key"         { type = string }
variable "cloudflare_api_token" { type = string }
variable "cloudflare_zone_name" { type = string }
variable "cloudflare_hostname"  { type = string }
variable "vultr_region"         { type = string  default = "ewr" }
variable "vultr_plan"           { type = string  default = "vc2-1c-2gb" }
variable "ssh_key_id"           { type = string  default = "" }
