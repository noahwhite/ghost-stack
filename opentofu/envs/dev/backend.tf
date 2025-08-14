variable "r2_account_id" {}
variable "r2_access_key_id" {}
variable "r2_secret_access_key" {}

locals {
  r2_endpoint = "https://${var.r2_account_id}.r2.cloudflarestorage.com"
}

terraform {
  backend "s3" {
    endpoint                    = local.r2_endpoint
    bucket                      = "ghost-stack-dev-tofu-state"
    key                         = "dev/terraform.tfstate"
    region                      = "auto"
    access_key                  = var.r2_access_key_id
    secret_key                  = var.r2_secret_access_key
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    force_path_style            = true
  }
}