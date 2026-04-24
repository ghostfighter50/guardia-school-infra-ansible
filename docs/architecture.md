# Architecture

Technical architecture of the Guardia School infrastructure automation project.

---

## Overview

The project uses a push-based Ansible model. The controller connects to target machines over SSH,
applies configuration roles, and stores all secrets in a local HashiCorp Vault instance. Centreon
and OPNsense are documented integration points around the automation, not roles deployed by the
main playbook sequence.

---

## Infrastructure Topology

```
Ansible Controller (localhost)
  - Ansible 2.12+
  - HashiCorp Vault 1.15+
  - SSH key management
        |
        | SSH port 22 (bootstrap) -> 2222 (post-hardening)
        |
  ┌─────┴──────────────────────────────┐
  │ Reference network 10.1.90.0/24     │
  └─────┬──────────────────────────────┘
        |
Linux Targets (Ubuntu 22.04 / Debian 12)
  - SSH daemon (hardened, port 2222)
  - PAM TOTP (2FA on SSH login)
  - UFW firewall (deny-all default)
  - SNMP agent (monitoring)
  - fail2ban (brute-force protection)
        |
        | SNMP UDP/161
        |
Centreon Monitoring Server (optional)
  - Collects SNMP metrics
  - Generates alerts and trends

Optional OPNsense Gateway
  - External firewall/router reference
  - Documented in setup-opnsense.md
```

---

## Component Overview

### Ansible

| Property | Value |
|----------|-------|
| Mode | Push-based (agentless) |
| Protocol | SSH |
| Bootstrap port | 22 |
| Hardened port | 2222 |
| Auth | ED25519 key (service account) |
| Collections | ansible.posix, community.general, community.hashi_vault |

### HashiCorp Vault

| Property | Value |
|----------|-------|
| Version | 1.15+ |
| Address | http://127.0.0.1:8200 |
| Backend | KV v2 (versioned key-value) |
| Key sharing | Shamir 5 shards, 3-of-5 threshold |
| TLS | Disabled (lab environment) |
| Data path | /opt/vault/data |
| Init file | /root/vault_init.json (mode 0600) |

Vault secret structure:

```
secret/
  infra/
    bootstrap        # Bootstrap credentials
    admin            # Admin credentials
  hosts/
    <hostname>/
      admin_2fa      # Admin TOTP secret and scratch codes
      user           # Managed user password
      2fa            # Managed user TOTP secret and scratch codes
```

### SSH Hardening

| Property | Value |
|----------|-------|
| Port | 2222 |
| Root login | Disabled |
| Authentication | Public key + TOTP (keyboard-interactive) |
| Service account | Key-only (no TOTP) |
| Banner | /etc/ssh/banner.txt |
| TOTP library | libpam-google-authenticator |
| TOTP algorithm | HMAC-SHA1, 30-second window |

### UFW Firewall

| Policy | Direction | Protocol | Port | Source |
|--------|-----------|----------|------|--------|
| DENY (default) | Inbound | any | any | any |
| ALLOW | Inbound | TCP | 2222 | any |
| ALLOW | Inbound | UDP | 161 | monitoring source |
| ALLOW (default) | Outbound | any | any | any |

### SNMP Agent

| Property | Value |
|----------|-------|
| Version | SNMPv2c |
| Access | Read-only |
| Community | Configurable (default: public_ro) |
| Source restriction | Single IP (snmp_allowed_source) |
| Monitored metrics | CPU, memory, disk, network, uptime |

---

## Deployment Sequence

```
1. Bootstrap (00_service_account.yml)
   Controller -> each target via SSH password
   Creates ansible user with key + sudo

2. Vault (01_vault.yml)
   Controller -> localhost
   Installs Vault, initializes, seeds secrets

3. Harden (03_harden.yml)
   Controller -> all targets via SSH key
   Roles: common -> ssh_hardening -> ufw_firewall -> snmp_agent -> managed_user
```

---

## Role Responsibilities

| Role | Target | When |
|------|--------|------|
| `service_account` | Each target | Once, bootstrap |
| `vault_server` | Controller | Once, before hardening |
| `common` | All targets | Each run |
| `ssh_hardening` | All targets | Each run |
| `ufw_firewall` | All targets | Each run |
| `snmp_agent` | All targets | Each run |
| `managed_user` | All targets | Each run |

---

## Security Model

### Authentication layers

1. SSH key required (ansible ED25519 key)
2. TOTP code required (all users except ansible service account)
3. fail2ban blocks brute-force (5 failures -> 1-hour ban)

### Secrets management

All credentials are generated randomly and stored in Vault at deploy time.
No hardcoded secrets in playbooks or variable files (except defaults marked ChangeMe).

### Network isolation

UFW deny-all inbound ensures only explicitly permitted traffic reaches targets.
SNMP is restricted to a single monitoring source IP.

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [installation.md](installation.md) | Step-by-step deployment guide |
| [file-reference.md](file-reference.md) | Every file in the project explained |
| [setup-vault.md](setup-vault.md) | Vault setup and operations |
| [setup-ssh.md](setup-ssh.md) | SSH hardening details |
| [setup-firewall.md](setup-firewall.md) | UFW firewall configuration |
| [setup-opnsense.md](setup-opnsense.md) | OPNsense gateway integration |
