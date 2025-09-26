run "tailscale_auth_key_tests" {
  command = plan

  plan_options {
    refresh = false
  }

  module {
    source = "../../modules/tailscale"
  }

  assert {
    condition     = tailscale_tailnet_key.this.preauthorized == true
    error_message = "Tailscale key should be preauthorized"
  }

  assert {
    condition     = tailscale_tailnet_key.this.reusable == true
    error_message = "Tailscale key should be reusable"
  }

  assert {
    condition     = tailscale_tailnet_key.this.ephemeral == false
    error_message = "Tailscale key should not be ephemeral"
  }

  assert {
    condition     = tailscale_tailnet_key.this.description == "Dev Ghost pre-approved auth key"
    error_message = "Tailscale key should not be ephemeral"
  }

}

run "acl-policy-is-correct" {
  command = plan

  plan_options {
    refresh = false
  }

  module {
    source = "../../modules/tailscale"
  }

  assert {
    condition     = tailscale_acl.my_tailnet_acl.acl != null
    error_message = "ACL should not be null"
  }

  assert {
    condition = (
      length(jsondecode(tailscale_acl.my_tailnet_acl.acl).grants) == 1 &&
      contains(jsondecode(tailscale_acl.my_tailnet_acl.acl).grants[0].src, "noah@noahwhite.net") &&
      contains(jsondecode(tailscale_acl.my_tailnet_acl.acl).grants[0].dst, "tag:ghost-dev") &&
      contains(jsondecode(tailscale_acl.my_tailnet_acl.acl).grants[0].ip, "22")
    )
    error_message = "ACL grants should contain correct source, destination, and port 22"
  }

  assert {
    condition = (
      length(jsondecode(tailscale_acl.my_tailnet_acl.acl).ssh) == 1 &&
      jsondecode(tailscale_acl.my_tailnet_acl.acl).ssh[0].action == "accept" &&
      contains(jsondecode(tailscale_acl.my_tailnet_acl.acl).ssh[0].src, "noah@noahwhite.net") &&
      contains(jsondecode(tailscale_acl.my_tailnet_acl.acl).ssh[0].dst, "tag:ghost-dev") &&
      contains(jsondecode(tailscale_acl.my_tailnet_acl.acl).ssh[0].users, "root") &&
      contains(jsondecode(tailscale_acl.my_tailnet_acl.acl).ssh[0].users, "autogroup:nonroot") &&
      contains(jsondecode(tailscale_acl.my_tailnet_acl.acl).ssh[0].users, "core")
    )
    error_message = "SSH rules should allow access from noah@noahwhite.net to tag:ghost-dev with correct users"
  }

  assert {
    condition = (
      contains(keys(jsondecode(tailscale_acl.my_tailnet_acl.acl).groups), "group:devs") &&
      contains(jsondecode(tailscale_acl.my_tailnet_acl.acl).groups["group:devs"], "noah@noahwhite.net")
    )
    error_message = "Groups should contain group:devs with noah@noahwhite.net as member"
  }

  assert {
    condition = (
      contains(keys(jsondecode(tailscale_acl.my_tailnet_acl.acl).tagOwners), "tag:ghost-dev") &&
      contains(jsondecode(tailscale_acl.my_tailnet_acl.acl).tagOwners["tag:ghost-dev"], "group:devs")
    )
    error_message = "Tag owners should assign tag:ghost-dev to group:devs"
  }
}