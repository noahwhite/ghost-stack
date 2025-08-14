provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_r2_bucket" "state" {
  account_id = var.cloudflare_account_id
  name       = var.bucket_name
  location   = "NA" # Example: North America
}

output "r2_bucket_name" {
  value = cloudflare_r2_bucket.state.name
}