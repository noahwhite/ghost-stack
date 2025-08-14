output "cloudflare_nameservers" {
  value       = cloudflare_zone.main.name_servers
  description = "The nameservers to set at your registrar (e.g. Porkbun)"
}