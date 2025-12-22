terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.22.0"
    }
  }
}

resource "tailscale_tailnet_key" "this" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  description   = "Dev Ghost pre-approved auth key"
  tags          = ["tag:ghost-dev"]
}

resource "tailscale_acl" "my_tailnet_acl" {
  acl = jsonencode({
    "grants" = [
      {
        "src" : ["noah@noahwhite.net"],
        "dst" : ["tag:ghost-dev"],
        "ip" : ["22"]
      },
      {
        "src" : ["noah@noahwhite.net"],
        "dst" : ["tag:ghost-dev-workstation"],
        "ip" : ["22",
          "tcp:21118",
          "udp:21119",
          "udp:43178",
        "tcp:21119"]
      }
    ],
    "ssh" = [
      # SSH access rules
      {
        "action" = "accept",
        "src"    = ["noah@noahwhite.net"],
        "dst"    = ["tag:ghost-dev"],
        "users"  = ["root", "autogroup:nonroot", "core"],
      },
      {
        "action" = "check",
        "src"    = ["noah@noahwhite.net"],
        "dst"    = ["tag:ghost-dev-workstation"],
        "users"  = ["noah"],
      }
    ],
    "groups" = {
      "group:devs" = ["noah@noahwhite.net"],
    },
    "tagOwners" = {
      "tag:ghost-dev"             = ["group:devs"],
      "tag:ghost-dev-workstation" = ["group:devs"]
    },
  })
}