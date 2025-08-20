resource "cloudflare_r2_bucket" "state" {
  account_id    = var.cloudflare_account_id
  name          = var.r2_bucket_name
  storage_class = "Standard"
  location      = "enam" # East North America
}

output "r2_bucket_name" {
  value = cloudflare_r2_bucket.state.name
}