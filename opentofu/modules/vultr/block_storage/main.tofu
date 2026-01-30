terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "= 2.22.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# Block storage resource - attachment is handled separately via null_resource
# due to Vultr provider bug: https://github.com/vultr/terraform-provider-vultr/issues/660
resource "vultr_block_storage" "this" {
  region  = var.region
  size_gb = var.size_gb
  label   = var.label
  live    = true

  # Ignore attachment changes - managed by null_resource below to work around
  # provider bug. This prevents Terraform from trying to detach/reattach.
  lifecycle {
    ignore_changes = [attached_to_instance]
  }
}

# Workaround for Vultr provider bug #660
# The provider fails to attach block storage to recreated instances with:
# Error: error getting block storage: {"error":"Nothing to change","status":400}
#
# This null_resource uses the Vultr CLI to handle attachment.
# It inherits VULTR_API_KEY from the environment (set via TF_VAR_vultr_api_key in CI).
resource "null_resource" "attach_block_storage" {
  count = var.mount_instance_id != null ? 1 : 0

  triggers = {
    instance_id      = var.mount_instance_id
    block_storage_id = vultr_block_storage.this.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e

      # API key is inherited from environment (VULTR_API_KEY or TF_VAR_vultr_api_key)
      export VULTR_API_KEY="$${VULTR_API_KEY:-$TF_VAR_vultr_api_key}"
      if [ -z "$VULTR_API_KEY" ]; then
        echo "ERROR: VULTR_API_KEY or TF_VAR_vultr_api_key must be set"
        exit 1
      fi

      BLOCK_STORAGE_ID="${vultr_block_storage.this.id}"
      INSTANCE_ID="${var.mount_instance_id}"

      echo "Waiting for instance to be fully ready..."
      sleep 30

      echo "Checking current block storage state..."
      CURRENT_ATTACHED=$(vultr-cli block-storage get "$BLOCK_STORAGE_ID" | tail -n1 | awk '{print $3}')
      echo "Currently attached to: $${CURRENT_ATTACHED:-none}"

      # If attached to something (possibly stale/deleted instance), detach first
      if [ -n "$CURRENT_ATTACHED" ] && [ "$CURRENT_ATTACHED" != "$INSTANCE_ID" ]; then
        echo "Detaching from previous instance..."
        vultr-cli block-storage detach "$BLOCK_STORAGE_ID" --live || true

        echo "Waiting for detach to complete..."
        sleep 15
      fi

      # Attach to the new instance
      echo "Attaching block storage to instance $INSTANCE_ID..."
      vultr-cli block-storage attach "$BLOCK_STORAGE_ID" --instance="$INSTANCE_ID" --live || true

      # Verify attachment
      echo "Verifying block storage attachment..."
      sleep 5
      VERIFIED_ATTACHED=$(vultr-cli block-storage get "$BLOCK_STORAGE_ID" | tail -n1 | awk '{print $3}')

      if [ "$VERIFIED_ATTACHED" = "$INSTANCE_ID" ]; then
        echo "Verification successful: block storage is attached to $INSTANCE_ID"
      else
        echo "WARNING: Block storage may not be properly attached"
        echo "Expected: $INSTANCE_ID"
        echo "Actual: $${VERIFIED_ATTACHED:-none}"
        exit 1
      fi
    EOT
  }

  depends_on = [vultr_block_storage.this]
}
