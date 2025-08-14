variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "cloudflare_account_id" {
  type      = string
  sensitive = true
}

variable "bucket_name" {
  type    = string
  default = "ghost-stack-state"
}
