# Installation & Setup Guide

Complete step-by-step guide to deploy the Guardia School infrastructure automation project.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Step 1: Bootstrap Ansible Service Account](#step-1-bootstrap-ansible-service-account)
4. [Step 2: Deploy HashiCorp Vault](#step-2-deploy-hashicorp-vault)
5. [Step 3: Harden Linux Targets](#step-3-harden-linux-targets)
6. [Step 4: Verify Deployment](#step-4-verify-deployment)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Controller Machine Requirements

Your Ansible controller must have:

- **OS**: Linux (Ubuntu 22.04 LTS, Debian 12, or similar)
- **Python**: 3.10 or newer
- **Ansible**: 2.12 or newer

### Install Ansible

```bash
# Update package manager
sudo apt update

# Install Ansible
sudo apt install -y ansible

# Verify installation
ansible --version
# Output: ansible [core 2.15.x]
```

### Install Required Collections

```bash
# Clone or download the project
git clone <repository-url>
cd guardia-school-ansible

# Install collections from requirements.yml
ansible-galaxy collection install -r requirements.yml

# Verify collections installed
ansible-galaxy collection list | grep -E "ansible.posix|community"
```

### Generate SSH Key

Generate an ED25519 SSH key for the Ansible service account:

```bash
# Generate key pair
ssh-keygen -t ed25519 -f ~/.ssh/ansible_id_ed25519 -N ""

# Set secure permissions
chmod 600 ~/.ssh/ansible_id_ed25519
chmod 644 ~/.ssh/ansible_id_ed25519.pub

# Verify key
ssh-keygen -l -f ~/.ssh/ansible_id_ed25519
```

### Target Machine Requirements

Each target machine must have:

- **OS**: Ubuntu 22.04 LTS or Debian 12
- **SSH**: OpenSSH 7.4+ (8.7+ recommended)
- **Python**: 3.9+
- **Network**: Connectivity to Ansible controller

### Network Requirements

- Ansible controller <-> Targets: SSH on port 22 (bootstrap) -> 2222 (after hardening)
- Controller -> Targets: HTTPS on port 8200 (Vault)
- Monitoring <- Targets: SNMP on UDP/161

---

## Pre-Deployment Checklist

Complete these steps before beginning deployment:

- [ ] Ansible version ≥ 2.12: `ansible --version`
- [ ] Collections installed: `ansible-galaxy collection list`
- [ ] SSH key generated: `ls -la ~/.ssh/ansible_id_ed25519*`
- [ ] Inventory populated: `cat inventory/hosts.yml`
- [ ] Target machines have SSH access: `ssh -i ~/.ssh/ansible_id_ed25519 admin@<target-ip>`
- [ ] Target machines have Python: `ssh admin@<target-ip> python3 --version`
- [ ] Network connectivity verified (ping all targets)

---

## Step 1: Bootstrap Ansible Service Account

### Purpose

Create the `ansible` service account on each target machine with SSH key-based authentication and passwordless sudo.

### Requirements

- SSH password access to target (use `-k` flag)
- Admin/sudo access on target (use `-K` for the bootstrap playbook)

### Commands

```bash
# Update inventory file with target IPs
vim inventory/hosts.yml

# Example inventory
#
# all:
#   children:
#     firewall:
#       hosts:
#         opnsense:
#           ansible_host: 10.1.90.1
#     linux_targets:
#       hosts:
#         linux-test:
#           ansible_host: 10.1.90.10

# Run bootstrap playbook (prompts for SSH password and sudo password)
ansible-playbook playbooks/00_service_account.yml -k -K

# You'll be prompted:
# SSH password: <enter admin password>
# BECOME password: <enter sudo password>
```

### What Happens

1. Connects as `admin` user with password auth
2. Creates `ansible` user account
3. Creates `.ssh` directory with correct permissions
4. Copies your public key to target's `~ansible/.ssh/authorized_keys`
5. Configures sudoers: `ansible` can run any command without password

### Verify Success

```bash
# Test SSH key-based login (should succeed without password)
ssh -i ~/.ssh/ansible_id_ed25519 ansible@<target-ip>

# Test passwordless sudo
ssh -i ~/.ssh/ansible_id_ed25519 ansible@<target-ip> sudo whoami
# Output: root
```

### Duration

~2-3 minutes per target

### Next Step

Proceed to [Step 2: Deploy HashiCorp Vault](#step-2-deploy-hashicorp-vault)

---

## Step 2: Deploy HashiCorp Vault

### Purpose

Deploy and initialize HashiCorp Vault on the Ansible controller. This is where all secrets are stored.

### Requirements

- Ansible service account configured on controller
- Enough disk space for Vault data (`/opt/vault/data`)
- Port 8200 available on controller

### Commands

```bash
# Run Vault deployment playbook
ansible-playbook playbooks/01_vault.yml -K

# You'll be prompted:
# BECOME password: <enter sudo password for controller>
```

### What Happens

1. Installs Vault binary and dependencies
2. Creates `/opt/vault/data` directory
3. Deploys Vault HCL configuration
4. Starts Vault systemd service
5. Initializes Vault with Shamir secret sharing (5 shards, 3-of-5 threshold)
6. Unseals Vault automatically
7. Enables KV v2 secret engine
8. Seeds initial secrets (`infra/bootstrap`, `infra/admin`)
9. Exports `VAULT_ADDR` in shell environment

### Critical Output

After successful run:

```
vault_init_output.json created at /root/vault_init.json (mode 0600)
```

**IMPORTANT**: Back up `/root/vault_init.json` immediately to secure location.

### Verify Success

```bash
# Set Vault address in environment
export VAULT_ADDR="http://127.0.0.1:8200"

# Check Vault status
ansible localhost -m ansible.builtin.uri \
  -a 'url=http://127.0.0.1:8200/v1/sys/health'

# Expected output includes: "sealed": false
```

### Duration

~5 minutes

### ⚠️ Critical Security Notes

1. **Unseal Keys**: The 5 unseal keys in `/root/vault_init.json` are needed to unseal Vault after restart
2. **Root Token**: Also stored in `vault_init.json`; treat like a password
3. **Backup**: Store `vault_init.json` on encrypted external drive or secure vault
4. **Rotation**: Change default seed passwords (in `roles/vault_server/defaults/main.yml`) before production

### Next Step

Proceed to [Step 3: Harden Linux Targets](#step-3-harden-linux-targets)

---

## Step 3: Harden Linux Targets

### Purpose

Apply all security hardening to target machines: SSH hardening, firewall, SNMP, 2FA, user provisioning.

### Requirements

- Vault running (Step 2 completed)
- Ansible service account configured (Step 1 completed)
- Targets reachable via SSH on port 22

### Commands

```bash
# Run full hardening playbook
ansible-playbook playbooks/03_harden.yml

# Or run specific roles with tags
ansible-playbook playbooks/03_harden.yml --tags common
ansible-playbook playbooks/03_harden.yml --tags ssh
ansible-playbook playbooks/03_harden.yml --tags firewall
ansible-playbook playbooks/03_harden.yml --tags snmp
ansible-playbook playbooks/03_harden.yml --tags users
```

### What Happens (in order)

1. **Common** (~1 min)
   - Updates apt cache
   - Installs base packages (curl, vim, htop, net-tools)
   - Installs TOTP libraries (libpam-google-authenticator, qrencode)
   - Installs fail2ban and unattended-upgrades
   - Configures fail2ban SSH jail

2. **SSH Hardening** (~1 min)
   - Deploys hardened sshd configuration
   - Enables PAM TOTP authentication
   - Generates admin TOTP secret
   - Displays QR code for admin 2FA
   - Stores admin TOTP in Vault

3. **UFW Firewall** (~1 min)
   - Installs UFW
   - Sets default policies (deny inbound, allow outbound)
   - Opens SSH port (2222)
   - Opens SNMP port (UDP/161) from monitoring source
   - Enables firewall

4. **SNMP Agent** (~2 min)
   - Installs snmpd and snmp tools
   - Deploys SNMP configuration
   - Tests SNMP connectivity
   - Enables snmpd service

5. **Managed User** (~2 min)
   - Creates managed user (deploy)
   - Generates random password
   - Forces password change on first login
   - Stores password in Vault
   - Generates TOTP for managed user
   - Stores TOTP in Vault

### What Gets Configured

**SSH**:
- Port: 2222 (non-standard)
- Root login: Disabled
- Password auth: Disabled (key-only)
- 2FA: Enabled for admin and managed users
- Banner: Legal warning displayed

**Firewall**:
- Default inbound: DENY
- Default outbound: ALLOW
- Exceptions: SSH (2222), SNMP (UDP/161)

**SNMP**:
- Community: `public_ro` (read-only)
- Source restriction: Configurable in `group_vars/all.yml`
- Monitoring: Disk, load, interfaces enabled

**2FA**:
- Type: TOTP (Time-based One-Time Password)
- Algorithm: HMAC-SHA1
- Window: 30 seconds
- Code length: 6 digits
- Recovery: 5 scratch codes per user

**Managed Users**:
- Username: `deploy` (configurable)
- Groups: `sudo` (can use sudo)
- Password: Random 24-character, stored in Vault
- TOTP: Enabled with QR code display

### Output Examples

```
TASK [ssh_hardening : Generate admin TOTP secret] ****
changed: [linux-target-01]

TASK [ssh_hardening : Display QR code] ****
│█████████████████████████████████████████│
│█ ▀▀▀ █▀█▄▀▀▀██▀█▄█▀▀▀▀ ▀ ██▀██ ▀▀▀ ██ █│
│█ ███ █▄▀▄███▀▄▀█ ▀▀▀▀ █ ▀█ ██ ███ ███ █│
│█ ███ █████▀▀▄▀██ ▀▀▀▀  ▀██ ▄▀ ███ ▀█▀ █│
│█ ███ █ ▀▀▀████ █▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀ ▀ █│
...

Scratch codes (one-time use):
1. 123456
2. 234567
...
```

### Duration

~8-10 minutes for all roles on single target

### Verify Success

```bash
# Verify SSH on new port
ssh -i ~/.ssh/ansible_id_ed25519 -p 2222 admin@<target-ip>

# Verify firewall is active
ssh -i ~/.ssh/ansible_id_ed25519 -p 2222 admin@<target-ip> sudo ufw status
# Output: Status: active

# Verify SNMP responds
snmpget -v2c -c public_ro <target-ip> .1.3.6.1.2.1.1.1.0

# Verify managed user exists
ssh -i ~/.ssh/ansible_id_ed25519 -p 2222 admin@<target-ip> id deploy
```

### ⚠️ Important Notes

1. **SSH Access Changes**: After hardening, SSH port becomes 2222
2. **First Admin Login**: Will prompt for TOTP code
3. **First Managed User Login**: Will force password change + TOTP setup
4. **Network Access**: Only SSH + SNMP allowed after hardening

### Next Step

Proceed to [Step 4: Verify Deployment](#step-4-verify-deployment)

---

## Step 4: Verify Deployment

### Verification Checklist

Complete these tests to verify full deployment:

```bash
# 1. Verify Vault is running and healthy
export VAULT_ADDR="http://127.0.0.1:8200"
curl -s $VAULT_ADDR/v1/sys/health | jq .sealed
# Expected: false

# 2. Verify SSH hardening on target
ssh -i ~/.ssh/ansible_id_ed25519 -p 2222 admin@<target-ip> sshd -t
# Expected: "configuration ok"

# 3. Verify Firewall is active
ssh -i ~/.ssh/ansible_id_ed25519 -p 2222 admin@<target-ip> sudo ufw status
# Expected: "Status: active"

# 4. Verify SNMP is listening
ssh -i ~/.ssh/ansible_id_ed25519 -p 2222 admin@<target-ip> sudo netstat -uln | grep 161
# Expected: LISTEN on UDP/161

# 5. Verify fail2ban is active
ssh -i ~/.ssh/ansible_id_ed25519 -p 2222 admin@<target-ip> sudo systemctl is-active fail2ban
# Expected: active

# 6. Verify managed user exists
ssh -i ~/.ssh/ansible_id_ed25519 -p 2222 admin@<target-ip> id deploy
# Expected: uid, gid, groups output

# 7. Test SNMP from controller
snmpget -v2c -c public_ro <target-ip> sysDescr.0
# Expected: SNMP response

# 8. Test login as managed user (will require TOTP)
ssh -i ~/.ssh/ansible_id_ed25519 -p 2222 deploy@<target-ip>
# Prompts for: Password, then TOTP code
```

### Success Indicators

- ✓ Vault responds to health check (sealed=false)
- ✓ sshd configuration validates successfully
- ✓ UFW status is "active"
- ✓ SNMP listens on UDP/161
- ✓ fail2ban is running
- ✓ Managed user account exists
- ✓ SNMP queries return data
- ✓ SSH login succeeds with TOTP

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| SSH connection refused | sshd not reloaded | Re-run ssh hardening role: `ansible-playbook playbooks/03_harden.yml --tags ssh` |
| Vault unreachable | Vault not started | Check: `systemctl status vault` on controller |
| SNMP no response | SNMP not running or blocked | Check: `systemctl status snmpd` and `ufw status` |
| 2FA prompt not appearing | PAM not configured | Re-run ssh hardening: `ansible-playbook playbooks/03_harden.yml --tags ssh` |
| Managed user login fails | Password not in Vault | Re-run managed_user role: `ansible-playbook playbooks/03_harden.yml --tags users` |

---

## Troubleshooting

### General Troubleshooting

```bash
# Run playbook with verbose output
ansible-playbook playbooks/03_harden.yml -vvv

# Run playbook with specific target
ansible-playbook playbooks/03_harden.yml -l linux-target-01

# Dry-run (check what would be done)
ansible-playbook playbooks/03_harden.yml --check

# Check connectivity to target
ansible linux_targets -m ansible.builtin.ping
```

### Vault Issues

```bash
# Check Vault service status
sudo systemctl status vault

# View Vault logs
sudo journalctl -u vault -n 50

# Manually unseal Vault if sealed
export VAULT_ADDR="http://127.0.0.1:8200"
vault operator unseal (use keys from /root/vault_init.json)

# Read stored secrets
vault kv get secret/infra/bootstrap
```

### SSH Issues

```bash
# Test SSH configuration syntax
ssh -i ~/.ssh/ansible_id_ed25519 admin@<target-ip> sudo sshd -t

# View SSH auth log
ssh -i ~/.ssh/ansible_id_ed25519 admin@<target-ip> sudo tail -f /var/log/auth.log

# Enable SSH debug logging on client
ssh -vvv -i ~/.ssh/ansible_id_ed25519 -p 2222 admin@<target-ip>
```

### SNMP Issues

```bash
# Test SNMP from client
snmpget -v2c -c public_ro <target-ip> sysDescr.0

# View SNMP configuration
ssh -i ~/.ssh/ansible_id_ed25519 admin@<target-ip> sudo cat /etc/snmp/snmpd.conf

# Check SNMP is listening
ssh -i ~/.ssh/ansible_id_ed25519 admin@<target-ip> sudo netstat -uln | grep 161
```

### Firewall Issues

```bash
# Check UFW status
ssh -i ~/.ssh/ansible_id_ed25519 admin@<target-ip> sudo ufw status verbose

# Check UFW logs
ssh -i ~/.ssh/ansible_id_ed25519 admin@<target-ip> sudo grep UFW /var/log/syslog | tail -10
```

---

## Next Steps

1. **User Training**: Teach team members how to log in with 2FA
2. **Documentation**: Update this guide with your specific IPs and settings
3. **Backup**: Store `/root/vault_init.json` in secure vault
4. **Rotation**: Implement secret rotation policy (Vault auto-rotation)
5. **Monitoring**: Integrate Centreon for SNMP monitoring (optional)

---

**Document Version**: 1.0  
**Last Updated**: 24 April 2026  
**Status**: Current and Complete
