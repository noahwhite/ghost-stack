# Vultr Block Storage Attachment Bug Analysis

**Date**: January 2026
**Related Issue**: [vultr/terraform-provider-vultr#660](https://github.com/vultr/terraform-provider-vultr/issues/660)
**Status**: Open (as of January 2026)

## Problem Summary

When a Vultr instance is recreated (destroyed and created with a new ID), the Vultr Terraform provider fails to attach existing block storage to the new instance. The error returned is:

```
Error: error getting block storage: {"error":"Nothing to change","status":400}
```

Despite this error, the provider updates its state to show the block storage as "attached," creating a state/reality mismatch. The Vultr console and the instance itself show the storage as unattached.

## Technical Analysis

### Provider Code Review

The issue is in `vultr/resource_vultr_block_storage.go` in the `resourceVultrBlockStorageUpdate` function:

```go
if d.HasChange("attached_to_instance") {
    old, newVal := d.GetChange("attached_to_instance")

    if old.(string) != "" {
        // Check if actually attached before detaching
        bs, _, err := client.BlockStorage.Get(ctx, d.Id())
        if bs.AttachedToInstance != "" {
            // Detach from old instance
            client.BlockStorage.Detach(ctx, d.Id(), blockReq)
        }
    }

    if newVal.(string) != "" {
        // Attach to new instance
        client.BlockStorage.Attach(ctx, d.Id(), blockReq)  // <-- Fails here
    }
}
```

### Root Cause Theories

1. **Stale API State**: When the old instance is destroyed, Vultr may auto-detach the storage but the API returns stale data showing it's still attached to the (now non-existent) instance.

2. **Race Condition**: The attachment request arrives before Vultr's backend fully processes the instance destruction or previous detachment.

3. **API Idempotency Bug**: The Vultr API may incorrectly return "Nothing to change" when the storage isn't actually attached to anything.

4. **Missing Verification**: The provider doesn't verify the attachment actually succeeded after calling the API - it assumes success if no error is returned from the Attach call itself, but the error comes from a subsequent Get call.

## Impact

- Block storage is not attached to the new instance
- Terraform/OpenTofu state shows storage as attached (false positive)
- Data on the block storage is inaccessible to the new instance
- Manual intervention required to fix

## Affected Versions

Confirmed affected:
- Vultr provider 2.22.1, 2.27.1, 2.28.0
- OpenTofu 1.11.1
- Terraform (various versions)

## Workaround Implemented

We implemented a workaround using a `null_resource` with a local-exec provisioner that:

1. Removes `attached_to_instance` from the `vultr_block_storage` resource (provider no longer manages attachment)
2. Uses the Vultr CLI to handle attachment after instance creation
3. Includes proper waiting, detachment of stale attachments, and retry logic

See: `opentofu/modules/vultr/block_storage/main.tofu`

## Manual Recovery Steps

If you encounter this issue without the workaround:

1. **Verify actual state** in Vultr console - check if storage is attached
2. **Manually attach** via Vultr console or CLI:
   ```bash
   vultr-cli block-storage attach <block-storage-id> --instance-id=<instance-id> --live=true
   ```
3. **Refresh Terraform state**:
   ```bash
   tofu refresh
   ```
4. Or **remove and re-import** the block storage resource:
   ```bash
   tofu state rm module.block_storage.vultr_block_storage.this
   tofu import module.block_storage.vultr_block_storage.this <block-storage-id>
   ```

## Monitoring

Watch the GitHub issue for updates: https://github.com/vultr/terraform-provider-vultr/issues/660

When fixed, the workaround can be removed and attachment management returned to the provider.
