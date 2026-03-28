terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.28.0"
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
  expiry        = 86400 # 24 hours - limits exposure window if state is compromised before first boot
  description   = "ghost-dev"
  tags          = ["tag:ghost-dev"]

  lifecycle {
    # Explicitly replace this key whenever the instance would be replaced.
    # This guarantees a fresh one-time key when the instance is recreated.
    # The instance_replacement_hash only changes on genuine infra changes — the
    # Infisical boot token is isolated from user_data via terraform_data.boot_token_snapshot
    # (GHO-85), so token consumption/renewal no longer triggers instance replacement.
    replace_triggered_by = [null_resource.instance_replacement_trigger]

    # Suppress recreation of the existing (already consumed) key when expiry is first added.
    # The next natural key rotation (via replace_triggered_by) will create with the 24h expiry.
    ignore_changes = [expiry]
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
      "tag:ghost-dev-workstation" = ["group:devs"],
      "tag:infisical"             = ["group:devs"]
    },
  })
}
