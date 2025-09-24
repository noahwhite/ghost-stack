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