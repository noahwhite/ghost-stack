terraform {
  required_providers {
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.16"
    }
  }
}

# ==========================================================================
# Project
# ==========================================================================

resource "infisical_project" "ghost" {
  name = "Ghost Stack"
  slug = "ghost-stack"
}

# ==========================================================================
# Boot-Time Machine Identity (ghost-dev)
#
# Used by instances to fetch application secrets at boot.
# Configured with single-use tokens so each token is consumed on first use.
# ==========================================================================

resource "infisical_identity" "ghost_dev" {
  name   = "ghost-dev"
  org_id = var.org_id
  role   = "no-access"
}

resource "infisical_identity_universal_auth" "ghost_dev" {
  identity_id                 = infisical_identity.ghost_dev.id
  access_token_num_uses_limit = 1
  access_token_ttl            = 300 # 5 minutes — enough to survive boot window
}

# Link identity to project with no-access base role.
# Actual permissions are granted via specific privilege below.
resource "infisical_project_identity" "ghost_dev" {
  project_id  = infisical_project.ghost.id
  identity_id = infisical_identity.ghost_dev.id

  roles = [{
    role_slug = "no-access"
  }]
}

# Scope identity to read secrets in the target environment only.
resource "infisical_project_identity_specific_privilege" "ghost_dev_read_env" {
  project_slug = infisical_project.ghost.slug
  identity_id  = infisical_identity.ghost_dev.id

  permissions_v2 = [
    {
      action  = ["read"]
      subject = "secrets"
      conditions = jsonencode({
        "environment" = { "$eq" = var.environment }
        "secretPath"  = { "$eq" = "/" }
      })
    }
  ]
}
