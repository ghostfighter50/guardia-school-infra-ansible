# File Reference

Complete reference for every file and directory in the project.

---

## Overview

This document describes the purpose of each file in the repository. Use it to understand
what to edit when making configuration changes.

---

## Root Directory

| File | Purpose |
|------|---------|
| `ansible.cfg` | Global Ansible settings: inventory path, SSH options, privilege escalation, roles path |
| `requirements.yml` | Ansible Galaxy collection dependencies |
| `bootstrap.sh` | Controller bootstrap helper: generate SSH key, install collections, print execution order |
| `README.md` | Project overview and quick start |
| `report.tex` | Final LaTeX technical report for the current repository state |

### ansible.cfg

Key settings:

| Setting | Value | Effect |
|---------|-------|--------|
| `inventory` | inventory/hosts.yml | Default inventory file |
| `roles_path` | roles/ | Where roles are loaded from |
| `remote_user` | ansible | Default SSH user for all connections |
| `private_key_file` | ~/.ssh/ansible_id_ed25519 | SSH key used by Ansible |
| `pipelining` | True | Reduces SSH round-trips, speeds up execution |

---

## inventory/

| File | Purpose |
|------|---------|
| `inventory/hosts.yml` | Static inventory: defines all managed hosts and groups |
| `inventory/group_vars/all.yml` | Variables applied to every host |
| `inventory/nmap_discovery.yml` | Optional helper inventory for discovery experiments |

### inventory/group_vars/all.yml

Key variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `ansible_service_user` | ansible | Name of the Ansible service account |
| `admin_user` | admin | Name of the human admin account on targets |
| `ssh_port` | 2222 | SSH port used after hardening |
| `snmp_community` | public_ro | SNMPv2c community string |
| `snmp_allowed_source` | 127.0.0.1 | IP allowed to query SNMP |
| `centreon_host_template` | OS-Linux-SNMP-custom | Centreon host template used for automatic registration |
| `centreon_poller_name` | poller-01 | Centreon poller name assigned to discovered hosts |
| `vault_addr` | http://127.0.0.1:8200 | Vault API address |

---

## playbooks/

| File | Purpose |
|------|---------|
| `00_service_account.yml` | Bootstrap service account on targets (run once with -k -K) |
| `01_vault.yml` | Deploy and initialize HashiCorp Vault on controller |
| `02_discover.yml` | Discover Linux VMs from nmap inventory and regenerate inventory/hosts.yml |
| `03_harden.yml` | Full hardening of all linux_targets |
| `04_centreon.yml` | Register discovered hosts in Centreon using the REST CLAPI API |
| `site.yml` | Full orchestration wrapper: runs 01_vault then 03_harden |

---

## roles/

### service_account

Creates the `ansible` system user used for all subsequent connections.

| File | Purpose |
|------|---------|
| `tasks/main.yml` | Creates user, .ssh directory, authorized_keys, sudoers entry |

### centreon_register

Registers discovered Linux hosts in Centreon using the documented REST CLAPI API.

| File | Purpose |
|------|---------|
| `tasks/main.yml` | Authenticate to Centreon, add missing hosts, set SNMP settings, apply template |
| `defaults/main.yml` | Centreon API URL, API auth source, template and poller defaults |

### vault_server

Installs and configures HashiCorp Vault on the controller.

| File | Purpose |
|------|---------|
| `tasks/main.yml` | Install, configure, initialize, unseal, enable KV v2, seed secrets |
| `defaults/main.yml` | Vault defaults: port, key shares, threshold, KV mount path |
| `templates/vault.hcl.j2` | Vault HCL configuration file |
| `handlers/main.yml` | Vault service restart handler |

Key defaults (`defaults/main.yml`):

| Variable | Default | Purpose |
|----------|---------|---------|
| `vault_listen_port` | 8200 | Port Vault listens on |
| `vault_init_key_shares` | 5 | Number of Shamir key shards |
| `vault_init_key_threshold` | 3 | Shards needed to unseal |
| `vault_kv_mount` | secret | KV v2 mount path |
| `vault_init_file` | /root/vault_init.json | Where init output is saved |

### common

Applies base configuration to all targets.

| File | Purpose |
|------|---------|
| `tasks/main.yml` | Install packages, configure fail2ban, enable unattended-upgrades |
| `handlers/main.yml` | fail2ban restart handler |

Installed packages: `curl`, `vim`, `htop`, `net-tools`, `fail2ban`, `unattended-upgrades`,
`libpam-google-authenticator`, `qrencode`

### ssh_hardening

Hardens the SSH daemon and configures PAM-based TOTP.

| File | Purpose |
|------|---------|
| `tasks/main.yml` | Deploy banner, deploy hardened sshd config, configure PAM, generate TOTP |
| `templates/99-hardening.conf.j2` | Drop-in sshd config with hardened settings |
| `files/banner.txt` | Legal warning banner displayed at SSH login |
| `handlers/main.yml` | sshd restart handler |

Key sshd settings (via 99-hardening.conf.j2):

| Setting | Value |
|---------|-------|
| Port | 2222 |
| PermitRootLogin | no |
| PasswordAuthentication | no |
| PubkeyAuthentication | yes |
| KbdInteractiveAuthentication | yes |
| AuthenticationMethods | publickey,keyboard-interactive |
| Match User ansible | AuthenticationMethods publickey |

### ufw_firewall

Configures UFW with a deny-all inbound policy.

| File | Purpose |
|------|---------|
| `tasks/main.yml` | Enable UFW, set default deny, add SSH and SNMP allow rules |

### snmp_agent

Installs and configures the NET-SNMP daemon.

| File | Purpose |
|------|---------|
| `tasks/main.yml` | Install snmpd, deploy config, enable service, run verification |
| `defaults/main.yml` | Default community string and allowed source |
| `templates/snmpd.conf.j2` | snmpd configuration with community, sysinfo, disk/load checks |
| `handlers/main.yml` | snmpd restart handler |

### managed_user

Provisions the `deploy` application user on each target.

| File | Purpose |
|------|---------|
| `tasks/main.yml` | Create user, generate password, generate TOTP, store all in Vault |
| `defaults/main.yml` | Username, groups, password length, force-change flag |

Key defaults:

| Variable | Default | Purpose |
|----------|---------|---------|
| `managed_user_name` | deploy | Username to create |
| `managed_user_groups` | sudo | Groups to add user to |
| `managed_user_password_length` | 24 | Random password length |
| `managed_user_force_password_change` | true | Force change on first login |

---

## docs/

| File | Purpose |
|------|---------|
| `index.md` | This documentation index |
| `installation.md` | End-to-end deployment tutorial |
| `architecture.md` | System design and components |
| `file-reference.md` | This file |
| `setup-vault.md` | Vault configuration tutorial |
| `setup-ssh.md` | SSH hardening tutorial |
| `setup-2fa.md` | TOTP 2FA tutorial |
| `setup-firewall.md` | UFW firewall tutorial |
| `setup-snmp.md` | SNMP agent tutorial |
| `setup-centreon.md` | Centreon integration tutorial |
| `setup-opnsense.md` | OPNsense integration tutorial |
| `troubleshooting.md` | Problem diagnosis reference |
| `validation.md` | Deployment validation checklist |

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [architecture.md](architecture.md) | System design context |
| [installation.md](installation.md) | How to deploy |
| [validation.md](validation.md) | Verify everything is working |
