terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.22.0"
    }
  }
}

resource "tailscale_tailnet_key" "this" {
  reusable     = true
  ephemeral    = false
  preauthorized = true
  description  = "Dev Ghost pre-approved auth key"
}