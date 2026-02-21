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
# Configured with Token Auth — tokens are generated per-provisioning-run
# by OpenTofu (GHO-75), injected into Ignition, and consumed once at boot.
# ==========================================================================

resource "infisical_identity" "ghost_dev" {
  name   = "ghost-dev"
  org_id = var.org_id
  role   = "member"
}

resource "infisical_identity_token_auth" "ghost_dev" {
  identity_id                 = infisical_identity.ghost_dev.id
  access_token_num_uses_limit = 1   # single-use — token consumed on first use
  access_token_ttl            = 300 # 5 minutes — enough to survive boot window
  access_token_max_ttl        = 300 # cap max TTL at method level
}

# Link identity to project with no-access project role.
# Org-level role is member (minimum to operate within the org).
# Actual secret access is granted via specific privilege below — scoped to dev env only.
resource "infisical_project_identity" "ghost_dev" {
  project_id  = infisical_project.ghost.id
  identity_id = infisical_identity.ghost_dev.id

  roles = [{
    role_slug = "no-access"
  }]
}

# Scope identity to read secrets in the target environment only.
# Two policies:
#   1. Allow read in the target environment at root path
#   2. Forbid all actions in any other environment (explicit deny — defence in depth)
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
    },
    {
      action   = ["read", "create", "edit", "delete"]
      subject  = "secrets"
      inverted = true
      conditions = jsonencode({
        "environment" = { "$ne" = var.environment }
      })
    }
  ]
}
