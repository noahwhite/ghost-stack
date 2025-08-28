output "cloudflare_nameservers" {
  value       = module.dns_zone.cloudflare_nameservers
  description = "The nameservers to set at your registrar (e.g. Porkbun)"
}

output "r2_bucket_name" {
  value       = module.state_bucket.r2_bucket_name
  description = "The name of the OpenTofu state bucket"
}

output "cloudflare_zone_id" {
  value = module.dns_zone.zone_id
  description = "The zone id for the Cloudflare account"
}