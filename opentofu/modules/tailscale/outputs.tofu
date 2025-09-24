output "tailscale_auth_key" {
  value       = tailscale_tailnet_key.this.key
  description = "Pre-authorized Tailscale auth key for dev Ghost instance"
  sensitive   = true
}