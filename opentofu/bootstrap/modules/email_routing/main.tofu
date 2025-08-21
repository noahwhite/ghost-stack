resource "cloudflare_email_routing_address" "forwarding_target" {
  account_id  = var.cloudflare_account_id
  email       = var.destination_email
}

resource "cloudflare_email_routing_rule" "forward" {
  zone_id = var.cloudflare_zone_id
  name    = "Forward rule"
  enabled = true

  actions = [{
    type = "forward"
    value = [var.destination_email]
  }]

  matchers = [{
    type = "literal"
    field = "to"
    value = var.source_email
  }]
}