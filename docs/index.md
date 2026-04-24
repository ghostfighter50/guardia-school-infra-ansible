# Documentation Index

Reference index for the Guardia School Infrastructure Automation project.

---

## Overview

This project automates the deployment and hardening of Linux infrastructure using Ansible,
HashiCorp Vault, UFW firewall, SNMP monitoring, and TOTP two-factor authentication.

---

## Documents

| Document | Type | Purpose |
|----------|------|---------|
| [installation.md](installation.md) | Tutorial | End-to-end deployment guide |
| [architecture.md](architecture.md) | Reference | System design and component overview |
| [file-reference.md](file-reference.md) | Reference | Every file and directory explained |
| [setup-vault.md](setup-vault.md) | Tutorial | HashiCorp Vault deployment and configuration |
| [setup-ssh.md](setup-ssh.md) | Tutorial | SSH hardening and PAM configuration |
| [setup-2fa.md](setup-2fa.md) | Tutorial | TOTP two-factor authentication setup |
| [setup-firewall.md](setup-firewall.md) | Tutorial | UFW firewall rules and configuration |
| [setup-snmp.md](setup-snmp.md) | Tutorial | SNMP agent setup and monitoring integration |
| [setup-centreon.md](setup-centreon.md) | Tutorial | Centreon monitoring platform integration |
| [setup-opnsense.md](setup-opnsense.md) | Tutorial | OPNsense gateway and network integration |
| [troubleshooting.md](troubleshooting.md) | Reference | Problem diagnosis and solutions |
| [validation.md](validation.md) | Checklist | Deployment validation and acceptance criteria |

---

## Playbook Sequence

| Playbook | Purpose | Typical run order |
|----------|---------|-------------------|
| `00_service_account.yml` | Bootstrap service account on fresh targets | 1 |
| `01_vault.yml` | Deploy and initialize Vault on controller | 2 |
| `02_discover.yml` | Discover VMs and regenerate `inventory/hosts.yml` | 3 |
| `03_harden.yml` | Apply hardening roles to discovered linux targets | 4 |
| `04_centreon.yml` | Register discovered hosts in Centreon through the API | 5 |
| `site.yml` | Wrapper for main deployment flow (01 + 03) | Alternative when inventory is already prepared |

---

## Navigation by Role

**Deploying for the first time**
Start with [installation.md](installation.md), then follow each setup guide in order.

**Understanding the system**
Read [architecture.md](architecture.md) then [file-reference.md](file-reference.md).

**Configuring a specific component**
Go directly to the relevant setup guide above.

**Diagnosing a problem**
Use [troubleshooting.md](troubleshooting.md).

**Validating a deployment**
Work through [validation.md](validation.md).

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [../README.md](../README.md) | Project overview and quick start |
