# Runbook: Tailscale Device Cleanup Before Instance Recreation

## Overview

This runbook documents the process of cleaning up stale Tailscale devices before recreating a Ghost instance. This prevents naming conflicts that cause the new instance to receive a suffixed hostname (e.g., `ghost-dev-01-1` instead of `ghost-dev-01`).

## Background

When an instance is destroyed and recreated, Tailscale keeps the old device registration in its inventory. When the new instance authenticates with the same hostname, Tailscale appends a suffix (e.g., `-1`) to avoid conflicts.

**Key behavior:** The `-1` suffix persists even after the old device is removed, since Tailscale considers the machine name "taken" at authentication time.

### Impact

- **SSH Access**: Works, but requires using the suffixed name (`tailscale ssh core@ghost-dev-01-1`)
- **Monitoring**: The `tailscale-monitor.service` may fail on first boot if it finds the stale device first (uses prefix matching with `head -n 1`)
- **Documentation/Scripts**: Any hardcoded references to `ghost-dev-01` will fail

## When to Use This Runbook

**Before** any operation that recreates a Ghost instance:

- Changes to `ghost.bu` (Butane/Ignition configuration)
- Sysext version updates (Tailscale, Alloy, docker-compose)
- Instance type changes
- Any OpenTofu change where the plan shows:
  ```
  # module.ghost_instance.vultr_instance.ghost must be replaced
  ```

## Prerequisites

- Admin access to Tailscale admin console
- Or: Tailscale API access with write permissions

## Procedure

### Option 1: Manual Cleanup via Admin Console (Recommended)

1. **Open Tailscale Admin Console**
   - Navigate to: https://login.tailscale.com/admin/machines

2. **Find the Device**
   - Search for the device name (e.g., `ghost-dev-01`)
   - Or filter by tag if using ACL tags

3. **Remove the Device**
   - Click on the device
   - Click the "..." menu (three dots)
   - Select "Remove device"
   - Confirm removal

4. **Verify Removal**
   - Refresh the machines page
   - Confirm the device is no longer listed

5. **Proceed with Infrastructure Changes**
   - Now run `tofu apply` to recreate the instance
   - The new instance will register with the correct hostname

### Option 2: CLI Cleanup

```bash
# List devices to find the device ID
tailscale status

# If you have API access, you can also use:
# curl -s -H "Authorization: Bearer $TAILSCALE_API_KEY" \
#   "https://api.tailscale.com/api/v2/tailnet/-/devices" | jq '.devices[] | {id, name, hostname}'

# Remove via the admin console (CLI removal requires API key with write access)
```

### Option 3: API Cleanup (Automation)

For future automation, devices can be removed via API:

```zsh
# Securely read the API key (zsh) - input will be hidden
read -s "TAILSCALE_API_KEY?Enter Tailscale API key: "
echo  # newline after hidden input
export TAILSCALE_API_KEY

# Get the device ID first
DEVICE_ID=$(curl -s -H "Authorization: Bearer $TAILSCALE_API_KEY" \
  "https://api.tailscale.com/api/v2/tailnet/-/devices" | \
  jq -r '.devices[] | select(.hostname == "ghost-dev-01") | .id')

# Delete the device
curl -X DELETE -H "Authorization: Bearer $TAILSCALE_API_KEY" \
  "https://api.tailscale.com/api/v2/device/$DEVICE_ID"

# Clear the variable when done
unset TAILSCALE_API_KEY
```

**Note:** This requires an API key with device write permissions. The current deployment uses auth keys for device registration, which is a different permission scope.

## Post-Recreation Verification

After the new instance is created:

1. **Check Device Name**
   ```bash
   # From the Tailscale admin console or via API
   # Device should be listed as "ghost-dev-01" (no suffix)
   ```

2. **Verify SSH Access**
   ```bash
   tailscale ssh core@ghost-dev-01
   ```

3. **Check Monitor Service**
   ```bash
   # On the instance
   systemctl status tailscale-monitor.timer
   systemctl status tailscale-monitor.service
   journalctl -u tailscale-monitor.service
   ```

## Troubleshooting

### Instance Registered with Suffixed Name

**Symptom:** New instance shows as `ghost-dev-01-1` in Tailscale

**Cause:** Old device was not removed before instance recreation

**Resolution Options:**

1. **Rename via CLI** (preserves current state):
   ```bash
   # On the instance
   sudo tailscale set --hostname=ghost-dev-01
   ```
   Then remove the old `ghost-dev-01` device from admin console.

2. **Recreate Instance** (clean approach):
   - Remove both devices from Tailscale admin
   - Run `tofu apply` with a change that forces recreation (e.g., add a comment to `ghost.bu`)

### Monitor Service Failed on First Boot

**Symptom:** `tailscale-monitor.service` shows failed status after instance creation

**Cause:** The monitor script found the stale device first during prefix matching

**Resolution:**
1. Remove the stale device from Tailscale admin
2. The timer will automatically retry the monitor service
3. Or manually restart: `sudo systemctl restart tailscale-monitor.service`

### Cannot Find Device in Admin Console

**Symptom:** Old device not visible in Tailscale admin

**Possible Causes:**
- Device was already removed
- Auth key has expired and device was auto-removed
- Looking at wrong tailnet

**Resolution:** Proceed with instance recreation - no cleanup needed

## Related Documentation

- Tailscale Machine Names: https://tailscale.com/kb/1098/machine-names
- Ghost Instance Configuration: `opentofu/modules/vultr/instance/userdata/ghost.bu`
- Tailscale Monitor Script: Located on block storage at `/var/mnt/storage/sbin/tailscale_monitor/`
- Tailscale Sysext Update Process: See CLAUDE.md "Updating Tailscale Sysext Version"

## Future Improvements

Consider automating device cleanup as part of the deployment workflow:

1. **Pre-destroy hook**: Remove device from Tailscale before `tofu apply`
2. **CI integration**: Add a step to deployment workflow that cleans up stale devices
3. **Idempotent naming**: Use instance ID or other unique identifier in hostname

These improvements would require:
- Tailscale API key with device write permissions stored in secrets
- Updates to `deploy-dev.yml` workflow
- Potentially a custom OpenTofu provider or local-exec provisioner
