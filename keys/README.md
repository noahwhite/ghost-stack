# SSH Public Keys

This directory contains SSH public keys used for infrastructure access.

## ghost-dev.pub

Copy your SSH public key here:

```bash
cp ~/.ssh/ghost-dev.pub keys/ghost-dev.pub
```

Or if your key is located elsewhere:

```bash
cp /path/to/your/key.pub keys/ghost-dev.pub
```

The key should be in OpenSSH format, typically starting with `ssh-ed25519` or `ssh-rsa`.

**Note**: Only public keys (.pub) should be stored here. Never commit private keys to version control!
