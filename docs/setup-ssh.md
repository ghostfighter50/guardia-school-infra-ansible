# SSH Hardening Setup

Guide to the SSH hardening configuration applied to all managed targets.

---

## Overview

The `ssh_hardening` role deploys a hardened OpenSSH configuration using a drop-in file
(`/etc/ssh/sshd_config.d/99-hardening.conf`), a legal banner, and PAM-based TOTP
two-factor authentication. The `ansible` service account is exempt from TOTP so automation
continues to work without interruption.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Ansible service account configured | Run 00_service_account.yml first |
| Vault deployed and unsealed | TOTP secrets are stored in Vault |
| Target OS | Ubuntu 22.04 / Debian 12 with OpenSSH 8.7+ |

---

## What Gets Configured

### sshd drop-in configuration

File deployed: `/etc/ssh/sshd_config.d/99-hardening.conf`

| Setting | Value | Reason |
|---------|-------|--------|
| Port | 2222 | Non-standard port reduces automated scan noise |
| PermitRootLogin | no | Prevents direct root access |
| PasswordAuthentication | yes | Allows password-based login when combined with TOTP |
| PubkeyAuthentication | yes | Required for key auth |
| KbdInteractiveAuthentication | yes | Required for TOTP prompt |
| AuthenticationMethods | publickey,keyboard-interactive password,keyboard-interactive | Allows either key + TOTP or password + TOTP |
| Match User ansible | AuthenticationMethods publickey | Key-only for service account |
| Banner | /etc/ssh/banner.txt | Legal warning at login |
| UsePAM | yes | Required for PAM TOTP |

### PAM configuration

File modified: `/etc/pam.d/sshd`

PAM is configured to call `pam_google_authenticator.so` as a required auth step.
The `nullok` option allows users without a TOTP secret to log in during initial provisioning,
after which TOTP secrets are always present.

### Legal banner

File deployed: `/etc/ssh/banner.txt`

Displayed to all users before authentication. Contains a standard unauthorized-access warning.

---

## Step 1: Run the Hardening Playbook

```bash
# Full hardening stack
ansible-playbook playbooks/03_harden.yml

# SSH role only
ansible-playbook playbooks/03_harden.yml --tags ssh
```

---

## Step 2: Retrieve the Admin TOTP Secret

After hardening, the admin TOTP secret is stored in Vault. Retrieve it and add it to an
authenticator app.

```bash
export VAULT_ADDR=http://127.0.0.1:8200

# Replace <hostname> with the actual target hostname
vault kv get secret/hosts/<hostname>/admin_2fa
```

The output includes:
- `secret`: The TOTP secret key (scan as QR or enter manually)
- `scratch_codes`: One-time backup codes for emergency access

Add the secret to any TOTP-compatible app (Google Authenticator, Authy, andOTP, etc.).

---

## Step 3: Test SSH Login

Test that SSH with key + TOTP works correctly:

```bash
# Connect as admin user (requires key + TOTP)
ssh -p 2222 admin@<target-ip>
# You will be prompted for a 6-digit TOTP code

# Connect as ansible user (key only, no TOTP prompt)
ssh -p 2222 -i ~/.ssh/ansible_id_ed25519 ansible@<target-ip>
```

---

## Verification

```bash
# Check sshd is listening on port 2222
ansible linux_targets -m command -a "ss -tuln | grep 2222" -b

# Check hardening config is deployed
ansible linux_targets -m command -a "cat /etc/ssh/sshd_config.d/99-hardening.conf" -b

# Check banner is deployed
ansible linux_targets -m command -a "cat /etc/ssh/banner.txt" -b

# Check PAM TOTP is configured
ansible linux_targets -m command -a "grep pam_google_authenticator /etc/pam.d/sshd" -b

# Test Ansible connectivity on new port
ansible linux_targets -m ping
```

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [setup-2fa.md](setup-2fa.md) | TOTP app setup and usage |
| [setup-firewall.md](setup-firewall.md) | UFW rule for SSH port 2222 |
| [troubleshooting.md](troubleshooting.md) | SSH and TOTP issue diagnosis |
