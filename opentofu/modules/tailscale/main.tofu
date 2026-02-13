terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.22.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

variable "instance_replacement_hash" {
  type        = string
  description = "Hash of all inputs that would cause instance replacement, triggering auth key regeneration"
  default     = ""
}

# Trigger resource for instance replacement
# When any input that would cause instance replacement changes, this resource
# is replaced, which in turn triggers replacement of the auth key
resource "null_resource" "instance_replacement_trigger" {
  triggers = {
    replacement_hash = var.instance_replacement_hash
  }
}

resource "tailscale_tailnet_key" "this" {
  reusable      = false # One-time key - invalidated after first use for security
  ephemeral     = false
  preauthorized = true
  description   = "ghost-dev"
  tags          = ["tag:ghost-dev"]

  lifecycle {
    # Explicitly replace this key whenever the instance would be replaced
    # This guarantees a fresh one-time key when the instance is recreated
    replace_triggered_by = [null_resource.instance_replacement_trigger]
  }
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