# Firewall Setup

Guide to the UFW firewall configuration applied to all managed targets.

---

## Overview

The `ufw_firewall` role configures UFW (Uncomplicated Firewall) with a deny-all inbound
policy. Only SSH (TCP/2222) and SNMP (UDP/161) are explicitly allowed. All outbound traffic
is permitted by default.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Ansible service account configured | Run 00_service_account.yml first |
| Target OS | Ubuntu 22.04 / Debian 12 |
| UFW package | Pre-installed on Ubuntu; installed by the common role on Debian |

---

## Default Policy

| Direction | Policy | Effect |
|-----------|--------|--------|
| Inbound | DENY | All traffic blocked unless explicitly allowed |
| Outbound | ALLOW | All traffic permitted |
| Routed | DENY | No forwarding |

---

## Allowed Rules

| Protocol | Port | Source | Purpose |
|----------|------|--------|---------|
| TCP | 2222 | any | SSH management access |
| UDP | 161 | `snmp_allowed_source` | SNMP queries from monitoring server |

The `snmp_allowed_source` variable is defined in `inventory/group_vars/all.yml`.
It must be set to the IP address of the monitoring server (Centreon poller or other).

---

## Step 1: Configure SNMP Source

Edit `inventory/group_vars/all.yml` and set the monitoring source IP:

```yaml
snmp_allowed_source: "10.1.91.10"   # Replace with your monitoring server IP
```

---

## Step 2: Apply Firewall Rules

```bash
# Full hardening stack (includes firewall)
ansible-playbook playbooks/02_harden.yml

# Firewall role only
ansible-playbook playbooks/02_harden.yml --tags firewall
```

What the role does:
1. Installs UFW if not present
2. Sets default inbound policy to DENY
3. Sets default outbound policy to ALLOW
4. Adds rule: TCP/2222 ALLOW from any
5. Adds rule: UDP/161 ALLOW from `snmp_allowed_source`
6. Enables UFW

---

## Step 3: Verify Rules

```bash
# Check UFW status on all targets
ansible linux_targets -m command -a "ufw status verbose" -b
```

Expected output:

```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)

To                         Action      From
--                         ------      ----
2222/tcp                   ALLOW IN    Anywhere
161/udp                    ALLOW IN    10.1.91.10
```

---

## Adding Additional Rules

To open additional ports, edit `roles/ufw_firewall/tasks/main.yml`:

```yaml
- name: Allow custom port
  community.general.ufw:
    rule: allow
    port: "443"
    proto: tcp
```

Or run ad-hoc:

```bash
ansible linux_targets -m community.general.ufw -a "rule=allow port=443 proto=tcp" -b
```

---

## Verification

```bash
# UFW is active on all targets
ansible linux_targets -m command -a "ufw status | head -1" -b
# Expected: Status: active

# SSH port is open
ansible linux_targets -m command -a "ufw status | grep 2222" -b

# SNMP port is open for monitoring source
ansible linux_targets -m command -a "ufw status | grep 161" -b
```

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [setup-snmp.md](setup-snmp.md) | SNMP agent that uses UDP/161 |
| [setup-ssh.md](setup-ssh.md) | SSH daemon that uses TCP/2222 |
| [troubleshooting.md](troubleshooting.md) | Firewall issue diagnosis |
