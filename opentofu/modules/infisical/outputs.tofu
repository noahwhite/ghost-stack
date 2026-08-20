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
