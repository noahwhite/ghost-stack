output "project_id" {
  description = "Infisical project ID"
  value       = infisical_project.ghost.id
}

output "project_slug" {
  description = "Infisical project slug"
  value       = infisical_project.ghost.slug
}

output "ghost_dev_identity_id" {
  description = "Machine identity ID for ghost-dev. Note: the Universal Auth client ID is a separate value found in the Universal Auth tab in the Infisical console."
  value       = infisical_identity.ghost_dev.id
}

output "ghost_dev_boot_token" {
  description = "Single-use boot token for the ghost-dev instance (consumed once at first boot)"
  value       = infisical_identity_token_auth_token.ghost_dev_boot.token
  sensitive   = true
}
