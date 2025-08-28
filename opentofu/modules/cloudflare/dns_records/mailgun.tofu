terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.8"
    }
  }
}

resource "cloudflare_dns_record" "mailgun_spf" {
  zone_id = var.cloudflare_zone_id
  name    = "mg.separationofconcerns.dev"
  type    = "TXT"
  content = "\"v=spf1 include:mailgun.org ~all\""
  ttl     = 3600
}

resource "cloudflare_dns_record" "mailgun_dkim" {
  zone_id = var.cloudflare_zone_id
  name    = "krs._domainkey.mg"
  type    = "TXT"
  content = "\"k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDJnDUSVEK8ilpBzfCBcdPCiIECGDbASLQFtn1jFU4WIaBze67lg70VFiAqOORRS74HLI+v5yHB8+NqtLV24oN42bcbwaApKe5o3fVKQezOwazcpYYLz6TPp/YYG3oHFjfCjqRtxU2/IN32qPib8fb+0q++JXq0uhOhSrWS2d3eiQIDAQAB\""
  ttl     = 3600
}

resource "cloudflare_dns_record" "mailgun_mx_1" {
  zone_id  = var.cloudflare_zone_id
  name     = "mg"
  type     = "MX"
  content  = "mxa.mailgun.org"
  priority = 10
  ttl      = 3600
}

resource "cloudflare_dns_record" "mailgun_mx_2" {
  zone_id  = var.cloudflare_zone_id
  name     = "mg"
  type     = "MX"
  content  = "mxb.mailgun.org"
  priority = 10
  ttl      = 3600
}

resource "cloudflare_dns_record" "mailgun_tracking" {
  zone_id = var.cloudflare_zone_id
  name    = "email.mg"
  type    = "CNAME"
  content = "mailgun.org"
  ttl     = 3600
}