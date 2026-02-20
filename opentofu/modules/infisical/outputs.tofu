output "project_id" {
  description = "Infisical project ID"
  value       = infisical_project.ghost.id
}

output "project_slug" {
  description = "Infisical project slug"
  value       = infisical_project.ghost.slug
}

output "ghost_dev_identity_id" {
  description = "Machine identity ID for ghost-dev (used as clientId for Universal Auth token generation)"
  value       = infisical_identity.ghost_dev.id
}
