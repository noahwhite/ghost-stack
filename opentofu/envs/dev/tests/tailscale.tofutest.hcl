mock_provider "tailscale" {
  mock_resource "tailscale_tailnet_key" {
    defaults = {
      key = "tskey-auth-mock-1234"
    }
  }

  mock_resource "tailscale_acl" {
    defaults = {}
  }
}

mock_provider "null" {}

run "tailscale_auth_key_is_one_time" {
  command = plan

  plan_options {
    refresh = false
  }

  module {
    source = "../../modules/tailscale"
  }

  assert {
    condition     = tailscale_tailnet_key.this.preauthorized == true
    error_message = "Tailscale key must be preauthorized to allow automatic device registration"
  }

  assert {
    condition     = tailscale_tailnet_key.this.reusable == false
    error_message = "Tailscale key must be a one-time key (reusable = false) to prevent reuse after first boot"
  }

  assert {
    condition     = tailscale_tailnet_key.this.ephemeral == false
    error_message = "Tailscale key must not be ephemeral — device should persist in tailnet after auth"
  }

  assert {
    condition     = tailscale_tailnet_key.this.description == "ghost-dev"
    error_message = "Tailscale key description should be 'ghost-dev'"
  }

  assert {
    condition     = tailscale_tailnet_key.this.expiry == 86400
    error_message = "Tailscale key must expire in 24 hours (86400s) to limit state exposure window (GHO-84)"
  }
}

run "acl_policy_is_correct" {
  command = plan

  plan_options {
    refresh = false
  }

  module {
    source = "../../modules/tailscale"
  }

  assert {
    condition     = tailscale_acl.soc_tailnet_acl.acl != null
    error_message = "ACL should not be null"
  }

  assert {
    condition = (
      length(jsondecode(tailscale_acl.soc_tailnet_acl.acl).grants) == 2 &&
      contains(jsondecode(tailscale_acl.soc_tailnet_acl.acl).grants[0].src, "noah@noahwhite.net") &&
      contains(jsondecode(tailscale_acl.soc_tailnet_acl.acl).grants[0].dst, "tag:ghost-dev") &&
      contains(jsondecode(tailscale_acl.soc_tailnet_acl.acl).grants[0].ip, "22")
    )
    error_message = "ACL grants should contain correct source, destination, and port 22 for ghost-dev"
  }

  assert {
    condition = (
      contains(jsondecode(tailscale_acl.soc_tailnet_acl.acl).grants[1].src, "noah@noahwhite.net") &&
      contains(jsondecode(tailscale_acl.soc_tailnet_acl.acl).grants[1].dst, "tag:ghost-dev-workstation") &&
      contains(jsondecode(tailscale_acl.soc_tailnet_acl.acl).grants[1].ip, "22")
    )
    error_message = "ACL grants should contain correct source, destination, and ports for ghost-dev-workstation"
  }

  assert {
    condition = (
      length(jsondecode(tailscale_acl.soc_tailnet_acl.acl).ssh) == 2 &&
      jsondecode(tailscale_acl.soc_tailnet_acl.acl).ssh[0].action == "check" &&
      contains(jsondecode(tailscale_acl.soc_tailnet_acl.acl).ssh[0].src, "noah@noahwhite.net") &&
      contains(jsondecode(tailscale_acl.soc_tailnet_acl.acl).ssh[0].dst, "tag:ghost-dev") &&
      contains(jsondecode(tailscale_acl.soc_tailnet_acl.acl).ssh[0].users, "root") &&
      contains(jsondecode(tailscale_acl.soc_tailnet_acl.acl).ssh[0].users, "autogroup:nonroot") &&
      contains(jsondecode(tailscale_acl.soc_tailnet_acl.acl).ssh[0].users, "core")
    )
    error_message = "SSH rules should require re-auth (check) from noah@noahwhite.net to tag:ghost-dev with correct users"
  }

  assert {
    condition = (
      jsondecode(tailscale_acl.soc_tailnet_acl.acl).ssh[1].action == "check" &&
      contains(jsondecode(tailscale_acl.soc_tailnet_acl.acl).ssh[1].src, "noah@noahwhite.net") &&
      contains(jsondecode(tailscale_acl.soc_tailnet_acl.acl).ssh[1].dst, "tag:ghost-dev-workstation") &&
      contains(jsondecode(tailscale_acl.soc_tailnet_acl.acl).ssh[1].users, "noah")
    )
    error_message = "SSH rules should require re-auth (check) from noah@noahwhite.net to tag:ghost-dev-workstation with user noah"
  }

  assert {
    condition = (
      contains(keys(jsondecode(tailscale_acl.soc_tailnet_acl.acl).groups), "group:devs") &&
      contains(jsondecode(tailscale_acl.soc_tailnet_acl.acl).groups["group:devs"], "noah@noahwhite.net")
    )
    error_message = "Groups should contain group:devs with noah@noahwhite.net as member"
  }

  assert {
    condition = (
      contains(keys(jsondecode(tailscale_acl.soc_tailnet_acl.acl).tagOwners), "tag:ghost-dev") &&
      contains(jsondecode(tailscale_acl.soc_tailnet_acl.acl).tagOwners["tag:ghost-dev"], "group:devs")
    )
    error_message = "Tag owners should assign tag:ghost-dev to group:devs"
  }

  assert {
    condition = (
      contains(keys(jsondecode(tailscale_acl.soc_tailnet_acl.acl).tagOwners), "tag:ghost-dev-workstation") &&
      contains(jsondecode(tailscale_acl.soc_tailnet_acl.acl).tagOwners["tag:ghost-dev-workstation"], "group:devs")
    )
    error_message = "Tag owners should assign tag:ghost-dev-workstation to group:devs"
  }
}
