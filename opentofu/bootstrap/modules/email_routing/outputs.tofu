output "email_routing_rule_name" {
  value = cloudflare_email_routing_rule.forward.name
}

# output "email_routing_enabled_state" {
#   value = cloudflare_email_routing_settings.email_routing_settings.enabled
# }
