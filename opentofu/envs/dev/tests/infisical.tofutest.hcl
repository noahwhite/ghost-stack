mock_provider "infisical" {
  mock_resource "infisical_project" {
    defaults = {
      id           = "test-project-id"
      last_updated = "2026-01-01T00:00:00Z"
    }
  }

  mock_resource "infisical_identity" {
    defaults = {
      id         = "test-identity-id"
      auth_modes = []
    }
  }

  mock_resource "infisical_identity_token_auth" {
    defaults = {
      id = "test-token-auth-id"
    }
  }

  mock_resource "infisical_project_identity" {
    defaults = {
      membership_id = "test-membership-id"
    }
  }

  mock_resource "infisical_project_identity_specific_privilege" {
    defaults = {}
  }

  mock_resource "infisical_project_user" {
    defaults = {
      membership_id = "test-user-membership-id"
    }
  }
}

run "infisical_identity_is_single_use" {
  command = plan

  plan_options {
    refresh = false
  }

  module {
    source = "../../modules/infisical"
  }

  variables {
    org_id      = "test-org-id"
    admin_email = "noah@noahwhite.net"
  }

  assert {
    condition     = infisical_identity_token_auth.ghost_dev.access_token_num_uses_limit == 1
    error_message = "Boot-time identity must use single-use tokens (access_token_num_uses_limit = 1)"
  }

  assert {
    condition     = infisical_identity_token_auth.ghost_dev.access_token_ttl == 300
    error_message = "Boot-time identity token TTL must be 300 seconds (5 minutes)"
  }

  assert {
    condition     = infisical_identity_token_auth.ghost_dev.access_token_max_ttl == 300
    error_message = "Boot-time identity max token TTL must be capped at 300 seconds at the method level"
  }
}

run "infisical_project_configuration" {
  command = plan

  plan_options {
    refresh = false
  }

  module {
    source = "../../modules/infisical"
  }

  variables {
    org_id      = "test-org-id"
    admin_email = "noah@noahwhite.net"
  }

  assert {
    condition     = infisical_project.ghost.name == "Ghost Stack"
    error_message = "Project name should be 'Ghost Stack'"
  }

  assert {
    condition     = infisical_project.ghost.slug == "ghost-stack"
    error_message = "Project slug should be 'ghost-stack'"
  }

  assert {
    condition     = infisical_project_user.admin.roles[0].role_slug == "admin"
    error_message = "Human admin must have 'admin' project role"
  }
}

run "infisical_identity_configuration" {
  command = plan

  plan_options {
    refresh = false
  }

  module {
    source = "../../modules/infisical"
  }

  variables {
    org_id      = "test-org-id"
    admin_email = "noah@noahwhite.net"
  }

  assert {
    condition     = infisical_identity.ghost_dev.name == "ghost-dev"
    error_message = "Machine identity name should be 'ghost-dev'"
  }

  assert {
    condition     = infisical_identity.ghost_dev.role == "member"
    error_message = "Machine identity org-level role should be 'member' (minimum to operate within the org)"
  }

  assert {
    condition     = infisical_project_identity.ghost_dev.roles[0].role_slug == "no-access"
    error_message = "Project identity base role should be 'no-access' (specific privilege grants read access)"
  }
}

run "infisical_privilege_scoped_to_dev" {
  command = plan

  plan_options {
    refresh = false
  }

  module {
    source = "../../modules/infisical"
  }

  variables {
    org_id      = "test-org-id"
    environment = "dev"
    admin_email = "noah@noahwhite.net"
  }

  # Allow policy: read access scoped to target environment only
  assert {
    condition     = strcontains(infisical_project_identity_specific_privilege.ghost_dev_read_env.permissions_v2[0].conditions, "\"$eq\"")
    error_message = "Allow policy must use $eq operator to scope to the target environment"
  }

  assert {
    condition     = !strcontains(infisical_project_identity_specific_privilege.ghost_dev_read_env.permissions_v2[0].conditions, "secretPath")
    error_message = "Allow policy must not restrict by secretPath (all paths in env should be readable)"
  }

  assert {
    condition     = infisical_project_identity_specific_privilege.ghost_dev_read_env.permissions_v2[0].subject == "secrets"
    error_message = "Allow policy must target 'secrets' subject"
  }

  assert {
    condition     = contains(infisical_project_identity_specific_privilege.ghost_dev_read_env.permissions_v2[0].action, "read")
    error_message = "Allow policy must grant 'read' action"
  }

  # Forbid policy: deny all actions in any non-target environment
  assert {
    condition     = infisical_project_identity_specific_privilege.ghost_dev_read_env.permissions_v2[1].inverted == true
    error_message = "Second policy must be a forbid rule (inverted = true)"
  }

  assert {
    condition     = strcontains(infisical_project_identity_specific_privilege.ghost_dev_read_env.permissions_v2[1].conditions, "\"$ne\"")
    error_message = "Forbid policy must use $ne operator to block non-target environments"
  }

  assert {
    condition     = infisical_project_identity_specific_privilege.ghost_dev_read_env.permissions_v2[1].subject == "secrets"
    error_message = "Forbid policy must target 'secrets' subject"
  }
}
