resource "cloudflare_zone" "main" {
  name = var.cloudflare_zone_name

  account = {
    id = var.cloudflare_account_id
  }

  type = "full"
}