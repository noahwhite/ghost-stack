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
  # NOTE: attached_to_instance removed - managed by null_resource below
}

# Workaround for Vultr provider bug #660
# The provider fails to attach block storage to recreated instances with:
# Error: error getting block storage: {"error":"Nothing to change","status":400}
#
# This null_resource uses the Vultr API directly to handle attachment.
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
      API_KEY="$${VULTR_API_KEY:-$TF_VAR_vultr_api_key}"
      if [ -z "$API_KEY" ]; then
        echo "ERROR: VULTR_API_KEY or TF_VAR_vultr_api_key must be set"
        exit 1
      fi

      BLOCK_STORAGE_ID="${vultr_block_storage.this.id}"
      INSTANCE_ID="${var.mount_instance_id}"

      echo "Waiting for instance to be fully ready..."
      sleep 30

      echo "Checking current block storage state..."
      CURRENT_STATE=$(curl -s -H "Authorization: Bearer $API_KEY" \
        "https://api.vultr.com/v2/blocks/$BLOCK_STORAGE_ID")

      CURRENT_ATTACHED=$(echo "$CURRENT_STATE" | jq -r '.block.attached_to_instance // empty')
      echo "Currently attached to: $${CURRENT_ATTACHED:-none}"

      # If attached to something (possibly stale/deleted instance), detach first
      if [ -n "$CURRENT_ATTACHED" ] && [ "$CURRENT_ATTACHED" != "$INSTANCE_ID" ]; then
        echo "Detaching from previous instance..."
        curl -s -X POST -H "Authorization: Bearer $API_KEY" \
          -H "Content-Type: application/json" \
          -d '{"live": true}' \
          "https://api.vultr.com/v2/blocks/$BLOCK_STORAGE_ID/detach" || true

        echo "Waiting for detach to complete..."
        sleep 15
      fi

      # Attach to the new instance
      echo "Attaching block storage to instance $INSTANCE_ID..."
      ATTACH_RESULT=$(curl -s -w "\n%%{http_code}" -X POST \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"instance_id\": \"$INSTANCE_ID\", \"live\": true}" \
        "https://api.vultr.com/v2/blocks/$BLOCK_STORAGE_ID/attach")

      HTTP_CODE=$(echo "$ATTACH_RESULT" | tail -n1)
      RESPONSE_BODY=$(echo "$ATTACH_RESULT" | sed '$d')

      if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
        echo "Block storage attached successfully"
      elif echo "$RESPONSE_BODY" | grep -q "Nothing to change"; then
        echo "API reports no change needed, verifying attachment..."
      else
        echo "Attachment request returned HTTP $HTTP_CODE"
        echo "Response: $RESPONSE_BODY"
      fi

      # Verify attachment
      echo "Verifying block storage attachment..."
      sleep 5
      VERIFY_STATE=$(curl -s -H "Authorization: Bearer $API_KEY" \
        "https://api.vultr.com/v2/blocks/$BLOCK_STORAGE_ID")

      VERIFIED_ATTACHED=$(echo "$VERIFY_STATE" | jq -r '.block.attached_to_instance // empty')

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
