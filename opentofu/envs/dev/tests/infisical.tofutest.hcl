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
    org_id = "test-org-id"
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
    org_id = "test-org-id"
  }

  assert {
    condition     = infisical_project.ghost.name == "Ghost Stack"
    error_message = "Project name should be 'Ghost Stack'"
  }

  assert {
    condition     = infisical_project.ghost.slug == "ghost-stack"
    error_message = "Project slug should be 'ghost-stack'"
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
    org_id = "test-org-id"
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
  }

  assert {
    condition     = strcontains(infisical_project_identity_specific_privilege.ghost_dev_read_env.permissions_v2[0].conditions, "\"$eq\"")
    error_message = "Privilege conditions must use $eq operator to scope to the target environment"
  }

  assert {
    condition     = infisical_project_identity_specific_privilege.ghost_dev_read_env.permissions_v2[0].subject == "secrets"
    error_message = "Privilege must target 'secrets' subject"
  }

  assert {
    condition     = contains(infisical_project_identity_specific_privilege.ghost_dev_read_env.permissions_v2[0].action, "read")
    error_message = "Privilege must grant 'read' action"
  }
}
