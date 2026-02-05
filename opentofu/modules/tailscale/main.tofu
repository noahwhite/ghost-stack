terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.22.0"
    }
  }
}

variable "instance_config_hash" {
  type        = string
  description = "Hash of instance configuration that triggers auth key regeneration when instance is recreated"
  default     = ""
}

resource "tailscale_tailnet_key" "this" {
  reusable      = false # One-time key - invalidated after first use for security
  ephemeral     = false
  preauthorized = true
  # Include config hash in description to force key regeneration when instance config changes
  description = var.instance_config_hash != "" ? "ghost-dev-${substr(var.instance_config_hash, 0, 8)}" : "ghost-dev"
  tags        = ["tag:ghost-dev"]
}

resource "tailscale_acl" "soc_tailnet_acl" {
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
      # SSH access rules - check requires re-authentication for privileged access
      {
        "action" = "check",
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