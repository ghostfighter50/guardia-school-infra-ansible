# Vault Setup

Step-by-step guide to deploy and operate HashiCorp Vault for secrets management.

---

## Overview

HashiCorp Vault is the secrets backend for this project. All passwords, TOTP secrets, and
credentials are generated at deploy time and stored in Vault's KV v2 engine. Vault runs on
the Ansible controller at `http://127.0.0.1:8200`.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Ansible 2.12+ | With community.hashi_vault collection |
| Port 8200 free | On the controller |
| sudo access | On the controller (playbook uses become) |
| ~100 MB disk | For Vault binary and data at /opt/vault/data |

---

## Concepts

### Shamir Secret Sharing

Vault initializes with a split master key:
- 5 key shards are generated at initialization
- Any 3 shards can reconstruct the master key and unseal Vault
- Vault must be unsealed after every restart
- Never store all shards in the same location

### KV v2 Engine

The KV v2 engine stores versioned key-value secrets:
- Secrets are accessed at paths like `secret/infra/bootstrap`
- Every write creates a new version; old versions are retained
- The mount path for this project is `secret/`

---

## Step 1: Deploy Vault

Run the Vault playbook on the controller:

```bash
ansible-playbook playbooks/01_vault.yml -K
```

You will be prompted for the controller's sudo password.

What the playbook does:
1. Installs the Vault binary to `/usr/bin/vault`
2. Creates `/opt/vault/data` as the storage backend
3. Deploys `/etc/vault/vault.hcl` from the template
4. Enables and starts the `vault` systemd service
5. Initializes Vault (generates 5 unseal keys + root token)
6. Unseals Vault using the first 3 keys
7. Enables KV v2 at `secret/`
8. Seeds initial secrets under `secret/infra/`

---

## Step 2: Verify Installation

```bash
# Check the service is running
sudo systemctl status vault

# Check Vault is responding
export VAULT_ADDR=http://127.0.0.1:8200
vault status
```

Expected output from `vault status`:

```
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false
Total Shares    5
Threshold       3
Version         1.15.x
```

---

## Step 3: Save the Initialization Keys

The unseal keys and root token are saved at `/root/vault_init.json` (mode 0600).
This file is the only copy. Back it up securely before proceeding.

```bash
# View the file (on controller as root)
sudo cat /root/vault_init.json
```

The file contains:

```json
{
  "keys": ["shard1", "shard2", "shard3", "shard4", "shard5"],
  "keys_base64": ["..."],
  "root_token": "hvs.XXXXXX"
}
```

Distribute the 5 shards to different administrators. Store the root token in a secure
offline location. Do not leave it accessible on the controller in production.

---

## Step 4: Authenticate to Vault

```bash
export VAULT_ADDR=http://127.0.0.1:8200

# Log in with root token (use only for initial setup)
vault login <root_token>

# Verify you are authenticated
vault token lookup
```

---

## Step 5: Inspect Seeded Secrets

```bash
# List secret paths
vault kv list secret/infra/

# Read a secret
vault kv get secret/infra/bootstrap
```

---

## Unsealing After Restart

If the controller is rebooted, Vault starts sealed. Unseal with any 3 of the 5 shards:

```bash
export VAULT_ADDR=http://127.0.0.1:8200
vault operator unseal <shard1>
vault operator unseal <shard2>
vault operator unseal <shard3>
vault status
# Sealed: false
```

---

## Vault Secret Structure

| Path | Contents |
|------|---------|
| `secret/infra/bootstrap` | Bootstrap password |
| `secret/infra/admin` | Admin password |
| `secret/hosts/<hostname>/admin_2fa` | Admin TOTP secret and scratch codes |
| `secret/hosts/<hostname>/user` | Managed user password |
| `secret/hosts/<hostname>/2fa` | Managed user TOTP secret and scratch codes |

---

## Verification

```bash
# Vault is running
sudo systemctl is-active vault

# Vault is unsealed
vault status | grep "^Sealed"
# Expected: Sealed          false

# KV v2 enabled
vault secrets list | grep secret/

# Secrets exist
vault kv list secret/infra/
```

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [architecture.md](architecture.md) | How Vault fits into the overall system |
| [setup-2fa.md](setup-2fa.md) | How TOTP secrets are stored in Vault |
| [troubleshooting.md](troubleshooting.md) | Vault-specific troubleshooting |
