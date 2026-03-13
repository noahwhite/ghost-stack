# soc-cms

Ghost CMS configuration files for separationofconcerns.dev.

These files are applied via the Ghost Admin UI or API — they are **not** provisioned
via Ignition or managed by OpenTofu. This directory is the version-controlled source
of truth for CMS-level configuration.

## Files

### `redirects.yaml`

URL redirects for the Ghost instance. Maps old Typepad URLs to their Ghost slugs.

**Format:** Ghost's `301:` redirect format — a top-level `301:` key with
`/old-path: /new-slug/` pairs as children.

**To apply changes:**

1. Update `redirects.yaml` in this directory and merge via PR
2. Log into [Ghost Admin](https://admin.separationofconcerns.dev/ghost)
3. Navigate to **Settings** → **Labs**
4. Under **Redirects**, click **Upload redirects file**
5. Select the updated `redirects.yaml` from this directory

> **Note:** Uploading replaces the entire redirects configuration — there is no merge.
> Always ensure this file contains all active redirects before uploading.

**To verify after upload:**

```bash
curl -sI https://separationofconcerns.dev/soc/2013/10/docker-glassfish4.html | grep -i location
# Expected: Location: https://separationofconcerns.dev/docker-glassfish4/
```
