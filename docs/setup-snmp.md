# SNMP Agent Setup

Guide to the SNMP agent configuration applied to all managed targets.

---

## Overview

The `snmp_agent` role installs and configures NET-SNMP (`snmpd`) on each target. It enables
SNMPv2c read-only access restricted to a single monitoring source IP. Metrics exposed include
system information, CPU load, memory usage, disk usage, and network interfaces.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| Ansible service account configured | Run 00_service_account.yml first |
| UFW firewall configured | UDP/161 must be allowed from monitoring source |
| Monitoring source IP known | Set as `snmp_allowed_source` in group_vars |

---

## Configuration Variables

Set these in `inventory/group_vars/all.yml`:

| Variable | Default | Purpose |
|----------|---------|---------|
| `snmp_community` | public_ro | SNMPv2c community string (read-only) |
| `snmp_allowed_source` | 127.0.0.1 | IP address allowed to query SNMP |

Change `snmp_allowed_source` to the actual monitoring server IP before deployment.

---

## Step 1: Set Variables

Edit `inventory/group_vars/all.yml`:

```yaml
snmp_community: "public_ro"
snmp_allowed_source: "<poller-ip>"   # Replace with your monitoring/Centreon poller IP
```

---

## Step 2: Deploy SNMP Agent

```bash
# Full hardening stack
ansible-playbook playbooks/03_harden.yml

# SNMP role only
ansible-playbook playbooks/03_harden.yml --tags snmp
```

What the role does:
1. Installs `snmpd`
2. Deploys `/etc/snmp/snmpd.conf` from the template
3. Enables and starts the `snmpd` service
4. Runs a local `snmpget` to verify the agent responds

---

## Step 3: Verify from Target

```bash
# Test locally on the target
ansible linux_targets -m command -a "snmpget -v2c -c public_ro 127.0.0.1 sysDescr.0" -b
```

Expected output:

```
SNMPv2-MIB::sysDescr.0 = STRING: Linux linux-test ...
```

---

## Step 4: Verify from Monitoring Server

From the Centreon poller or monitoring server:

```bash
snmpget -v2c -c public_ro <target-ip> sysDescr.0
snmpwalk -v2c -c public_ro <target-ip> .1.3.6.1.2.1.1
```

---

## Exposed OIDs

| Category | OID prefix | Examples |
|----------|-----------|---------|
| System info | .1.3.6.1.2.1.1 | sysDescr, sysUpTime, sysLocation, sysContact |
| Interfaces | .1.3.6.1.2.1.2 | ifInOctets, ifOutOctets, ifOperStatus |
| CPU load | .1.3.6.1.4.1.2021.10 | laLoad.1 (1 min), laLoad.2 (5 min) |
| Memory | .1.3.6.1.4.1.2021.4 | memTotalReal, memAvailReal, memTotalFree |
| Disk | .1.3.6.1.4.1.2021.9 | dskTotal, dskAvail, dskPercent |

---

## Verification

```bash
# snmpd is running on all targets
ansible linux_targets -m command -a "systemctl is-active snmpd" -b
# Expected: active

# snmpd is listening on UDP/161
ansible linux_targets -m command -a "ss -uln | grep 161" -b

# SNMP responds to queries
ansible linux_targets -m command -a "snmpget -v2c -c public_ro 127.0.0.1 sysUpTimeInstance" -b
```

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [setup-firewall.md](setup-firewall.md) | UFW rule for UDP/161 |
| [setup-centreon.md](setup-centreon.md) | How Centreon uses SNMP to monitor targets |
| [troubleshooting.md](troubleshooting.md) | SNMP issue diagnosis |
