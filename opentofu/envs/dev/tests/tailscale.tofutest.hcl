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

  # tailscale_acl uses CustomizeDiff to fetch the current ACL via direct HTTP
  # calls during plan. mock_provider intercepts standard CRUD but not CustomizeDiff,
  # so override_resource is used to bypass plan computation for this resource.
  # ACL content is verified by code review of main.tofu rather than unit test.
  override_resource {
    target = tailscale_acl.soc_tailnet_acl
    values = {}
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
