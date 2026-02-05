# Tailscale Access Policy

This document defines the access control policy for Tailscale-based SSH access to ghost-stack infrastructure.

---

## Table of Contents

1. [Overview](#overview)
2. [Access Control Model](#access-control-model)
3. [Current Access Grants](#current-access-grants)
4. [Device Tags](#device-tags)
5. [SSH Access Rules](#ssh-access-rules)
6. [Auth Key Management](#auth-key-management)
7. [Onboarding New Users](#onboarding-new-users)
8. [Offboarding Users](#offboarding-users)
9. [Troubleshooting](#troubleshooting)
10. [Support Contacts](#support-contacts)

---

## Overview

All SSH access to ghost-stack infrastructure is managed through Tailscale. Direct SSH via public IP is not permitted - the Vultr firewall blocks port 22 from all sources except Tailscale.

**Key Principles:**

- **Zero Trust**: No implicit trust based on network location
- **Identity-Based**: Access tied to Tailscale identity (email)
- **Least Privilege**: Users only get access to resources they need
- **Auditable**: All access logged via Tailscale admin console

---

## Access Control Model

Access is managed through three Tailscale constructs:

| Construct | Purpose | Managed In |
|-----------|---------|------------|
| **Groups** | Logical grouping of users | ACL policy |
| **Tags** | Logical grouping of devices | ACL policy + device registration |
| **ACLs** | Rules defining who can access what | OpenTofu (`modules/tailscale/main.tofu`) |

### Architecture

```
Users (by email)
    │
    └─► Groups (group:devs, group:ops, etc.)
            │
            └─► ACL Rules
                    │
                    └─► Device Tags (tag:ghost-dev, etc.)
                            │
                            └─► Devices (ghost-dev-01, etc.)
```

---

## Current Access Grants

### Users

| User | Email | Groups | Access Level |
|------|-------|--------|--------------|
| Noah White | noah@noahwhite.net | group:devs | Full admin |

### Groups

| Group | Members | Purpose |
|-------|---------|---------|
| group:devs | noah@noahwhite.net | Development team with full infrastructure access |

---

## Device Tags

Tags are used to categorize devices and apply access rules.

| Tag | Purpose | Devices | Tag Owners |
|-----|---------|---------|------------|
| `tag:ghost-dev` | Development Ghost instances | ghost-dev-01 | group:devs |
| `tag:ghost-dev-workstation` | Developer workstations | Personal machines | group:devs |

### Tag Ownership

Tag owners can:
- Register new devices with their tags
- Manage devices tagged with their tags

Current tag ownership is defined in the ACL:

```json
"tagOwners": {
  "tag:ghost-dev": ["group:devs"],
  "tag:ghost-dev-workstation": ["group:devs"]
}
```

---

## SSH Access Rules

SSH access is controlled via Tailscale SSH rules, not traditional SSH keys.

### Current Rules

| Source | Destination | Action | Allowed Users | Notes |
|--------|-------------|--------|---------------|-------|
| noah@noahwhite.net | tag:ghost-dev | check | root, core, autogroup:nonroot | Requires re-authentication |
| noah@noahwhite.net | tag:ghost-dev-workstation | check | noah | Requires re-authentication |

### Action Types

| Action | Behavior |
|--------|----------|
| `accept` | Allow SSH access immediately |
| `check` | Require additional verification (MFA, device posture) |
| `deny` | Block SSH access |

### Check Mode Workflow

When connecting to devices with `check` action (including `tag:ghost-dev` servers):

1. Run `tailscale ssh core@ghost-dev-01`
2. Browser opens for re-authentication
3. Confirm your identity (MFA if configured on your Tailscale account)
4. SSH session establishes after verification

**Session Caching:** Tailscale caches your verification for approximately 12 hours. Subsequent SSH connections within this window won't require re-authentication.

### Connecting via SSH

```bash
# Connect to Ghost dev instance
tailscale ssh core@ghost-dev-01

# Connect as root (if needed)
tailscale ssh root@ghost-dev-01
```

**Note:** Traditional SSH (`ssh user@host`) will not work. You must use `tailscale ssh`.

---

## Auth Key Management

Auth keys are used to register new devices (servers) to the Tailnet.

### Key Types

| Type | Behavior | Use Case |
|------|----------|----------|
| **One-time** | Revoked after single use | Server provisioning (current approach) |
| **Reusable** | Can register multiple devices | Development/testing |
| **Ephemeral** | Device removed when offline | Temporary access |

### Current Configuration

Ghost instances use **one-time, pre-authorized** auth keys:

```hcl
resource "tailscale_tailnet_key" "this" {
  reusable      = false  # One-time
  ephemeral     = false  # Persistent device
  preauthorized = true   # No admin approval needed
  tags          = ["tag:ghost-dev"]
}
```

### Key Lifecycle

1. **Creation**: OpenTofu generates a fresh key during `tofu apply`
2. **Usage**: Instance uses key on first boot via `tailscale up --authkey=...`
3. **Revocation**: Key automatically revoked after single use
4. **Verification**: Key shows as "Revoked" in admin console

### Viewing Keys

- **Admin Console**: https://login.tailscale.com/admin/settings/keys
- Keys show status: Active, Used, Revoked, Expired

### Manual Key Creation (Emergency)

If OpenTofu-managed keys aren't working:

1. Go to https://login.tailscale.com/admin/settings/keys
2. Click "Generate auth key..."
3. Configure:
   - **Reusable**: OFF (one-time)
   - **Ephemeral**: OFF
   - **Pre-approved**: ON
   - **Tags**: Select `tag:ghost-dev`
   - **Expiration**: 1 day
4. Copy key and use in provisioning

---

## Onboarding New Users

### Prerequisites

- User must have a Tailscale account
- User's email must be known

### Process

1. **Add User to Group**

   Edit `opentofu/modules/tailscale/main.tofu`:

   ```hcl
   "groups" = {
     "group:devs" = [
       "noah@noahwhite.net",
       "newuser@example.com"  # Add new user
     ],
   }
   ```

2. **Add SSH Access Rule** (if different from existing rules)

   ```hcl
   "ssh" = [
     # Existing rules...
     {
       "action" = "accept",
       "src"    = ["newuser@example.com"],
       "dst"    = ["tag:ghost-dev"],
       "users"  = ["core"],  # Limit to specific user
     },
   ]
   ```

3. **Apply Changes**

   ```bash
   ./opentofu/scripts/tofu.sh dev plan
   ./opentofu/scripts/tofu.sh dev apply
   ```

4. **User Setup**

   New user must:
   - Install Tailscale on their device
   - Authenticate with their email
   - Verify they can connect: `tailscale ssh core@ghost-dev-01`

---

## Offboarding Users

### Process

1. **Remove from Groups**

   Edit `opentofu/modules/tailscale/main.tofu` and remove the user from all groups.

2. **Remove SSH Rules** (if user-specific rules exist)

3. **Apply Changes**

   ```bash
   ./opentofu/scripts/tofu.sh dev plan
   ./opentofu/scripts/tofu.sh dev apply
   ```

4. **Revoke Active Sessions**

   In Tailscale admin console:
   - Go to Users
   - Find the user
   - Revoke any active sessions

5. **Audit**

   Review recent access logs for the user in Tailscale admin console.

---

## Troubleshooting

### Not Logged In to Tailscale

**Symptom:** `tailscale ssh` fails or `tailscale status` shows "Logged out"

**Cause:** You must authenticate to Tailscale before accessing any devices on the Tailnet.

**Resolution:**

```bash
# Login to Tailscale (opens browser for authentication)
tailscale login

# Verify you're connected
tailscale status
```

After logging in, your device joins the Tailnet and you can access other devices based on ACL rules.

### Cannot Connect via Tailscale SSH

**Symptom:** `tailscale ssh` hangs or returns permission denied

**Checks:**

1. **Verify Tailscale is running and logged in:**
   ```bash
   tailscale status
   ```
   If it shows "Logged out", run `tailscale login` first.

2. **Verify device is visible:**
   ```bash
   tailscale status | grep ghost-dev
   ```

3. **Check ACL permissions:**
   - Go to https://login.tailscale.com/admin/acls
   - Verify your email is in the correct group
   - Verify SSH rules allow access

4. **Check device tags:**
   - Go to https://login.tailscale.com/admin/machines
   - Verify target device has correct tag

### Device Not Appearing in Tailnet

**Symptom:** New instance not visible in `tailscale status`

**Checks:**

1. **Verify auth key was consumed:**
   - Check https://login.tailscale.com/admin/settings/keys
   - Key should show as "Used" or "Revoked"

2. **Check instance logs:**
   ```bash
   # Via Vultr console or after SSH access is restored
   journalctl -u tailscale-auth.service
   journalctl -u tailscaled.service
   ```

3. **Verify instance has network connectivity:**
   - Check Vultr console for boot errors
   - Verify firewall allows outbound HTTPS

### Wrong Device Name (Suffixed)

**Symptom:** Device appears as `ghost-dev-01-1` instead of `ghost-dev-01`

**Cause:** Old device wasn't removed before reprovisioning

**Resolution:** See `docs/runbooks/tailscale-device-cleanup.md`

### MFA/Check Prompt Not Appearing

**Symptom:** SSH to workstation fails without MFA prompt

**Checks:**

1. Verify Tailscale client is up to date
2. Check browser for pending auth prompt
3. Verify `check` action is configured in SSH rules

---

## Support Contacts

| Issue Type | Contact | Method |
|------------|---------|--------|
| Access requests | Noah White | Email or Slack |
| Infrastructure issues | Noah White | Email or Slack |
| Tailscale platform issues | Tailscale Support | https://tailscale.com/contact/support |

### Escalation Path

1. **Self-service**: Check this document and related runbooks
2. **Team support**: Contact infrastructure owner (see above)
3. **Vendor support**: Tailscale support for platform issues

---

## Related Documentation

- [Tailscale Device Cleanup Runbook](./runbooks/tailscale-device-cleanup.md)
- [Token Rotation Runbook](./token-rotation-runbook.md) - Tailscale Auth Key section
- [CLAUDE.md](../CLAUDE.md) - Updating Tailscale Sysext Version
- [Tailscale ACLs Documentation](https://tailscale.com/kb/1018/acls)
- [Tailscale SSH Documentation](https://tailscale.com/kb/1193/tailscale-ssh)

---

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2026-02-05 | Noah White | Initial version |

---

## ACL Reference

The complete ACL is managed in `opentofu/modules/tailscale/main.tofu`. Current configuration:

```json
{
  "grants": [
    {
      "src": ["noah@noahwhite.net"],
      "dst": ["tag:ghost-dev"],
      "ip": ["22"]
    },
    {
      "src": ["noah@noahwhite.net"],
      "dst": ["tag:ghost-dev-workstation"],
      "ip": ["22", "tcp:21118", "udp:21119", "udp:43178", "tcp:21119"]
    }
  ],
  "ssh": [
    {
      "action": "check",
      "src": ["noah@noahwhite.net"],
      "dst": ["tag:ghost-dev"],
      "users": ["root", "autogroup:nonroot", "core"]
    },
    {
      "action": "check",
      "src": ["noah@noahwhite.net"],
      "dst": ["tag:ghost-dev-workstation"],
      "users": ["noah"]
    }
  ],
  "groups": {
    "group:devs": ["noah@noahwhite.net"]
  },
  "tagOwners": {
    "tag:ghost-dev": ["group:devs"],
    "tag:ghost-dev-workstation": ["group:devs"]
  }
}
```
