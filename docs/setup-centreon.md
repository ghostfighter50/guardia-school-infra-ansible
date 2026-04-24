# Centreon Integration

Guide to integrating managed targets with the Centreon monitoring platform.

---

## Overview

Centreon is an enterprise monitoring platform. This project configures targets with SNMP agents
that Centreon can query. Each target must be registered in Centreon with the correct host
template so that monitoring services (CPU, memory, disk, network) are applied automatically.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| SNMP agent deployed on all targets | See [setup-snmp.md](setup-snmp.md) |
| UFW allows UDP/161 from poller | See [setup-firewall.md](setup-firewall.md) |
| Centreon 24.x+ installed | Central server and at least one poller |
| Poller can reach targets on UDP/161 | Test with snmpget from poller |
| Centreon Plugin Pack for Linux SNMP | Must be installed before host creation |

---

## Centreon Architecture

```
Centreon Central Server
  - Web interface (configuration, dashboards, alerts)
  - Database (MariaDB)
  - Broker (event processing)
        |
        | Gorgone protocol (HTTPS)
        |
Centreon Poller
  - Monitoring engine (centengine)
  - Runs checks against targets
  - Sends results back to central
        |
        | SNMP UDP/161
        |
Linux Targets
  - snmpd responding on UDP/161
  - Community string: snmp_community
```

---

## Step 1: Install the Linux SNMP Plugin Pack

On the Centreon central server web interface:

1. Navigate to **Configuration > Plugin Packs**
2. Search for `Linux SNMP`
3. Click **Install** on the "Linux SNMP" pack
4. The pack installs:
   - Host template: `OS-Linux-SNMP-custom`
   - Service templates: CPU, Memory, Disk, Network, Uptime, Load

---

## Step 2: Configure SNMP Credentials in Centreon

1. Navigate to **Configuration > Commands > Check**
2. Verify SNMP macros are available (`$_HOSTSNMPCOMMUNITY$`)
3. Navigate to **Configuration > Hosts > Templates**
4. Open `OS-Linux-SNMP-custom`
5. Under **Custom macros**, set:

| Macro | Value | Description |
|-------|-------|-------------|
| `SNMPCOMMUNITY` | public_ro | Must match `snmp_community` in group_vars |
| `SNMPVERSION` | 2c | Protocol version |
| `SNMPPORT` | 161 | SNMP listening port |

---

## Step 3: Add a Poller

If a poller does not exist yet:

1. On the central server, navigate to **Configuration > Pollers > Pollers**
2. Click **Add**
3. Fill in:

| Field | Value |
|-------|-------|
| Name | poller-01 (or descriptive name) |
| IP address | Poller's IP address |
| SSH port | 22 |
| Gorgone port | 443 |

4. Click **Save**
5. Generate and deploy the poller configuration (see Step 7)

---

## Step 4: Add a Host

For each target machine:

1. Navigate to **Configuration > Hosts > Hosts**
2. Click **Add**
3. Fill in the **Host Configuration** tab:

| Field | Value |
|-------|-------|
| Name | linux-target-01 (match Ansible inventory name) |
| Alias | Descriptive name |
| IP address / DNS | Target IP (e.g. 10.1.91.102) |
| SNMP version | 2c |
| SNMP community | public_ro |
| Monitored from | Select the poller that can reach this target |

4. On the **Templates** tab:
   - Click **Add a new entry**
   - Select `OS-Linux-SNMP-custom`

5. Click **Save**

---

## Step 5: Apply Services from Template

After saving the host:

1. In the host edit view, click **Create services linked to template**
2. Centreon creates service checks for: CPU, Memory, Disk-/, Load, Network
3. Review each service and confirm thresholds are appropriate

Default thresholds for `OS-Linux-SNMP-custom`:

| Service | Warning | Critical |
|---------|---------|---------|
| CPU usage | 80% | 90% |
| Memory usage | 80% | 90% |
| Disk usage | 80% | 90% |
| Load (1 min normalized) | 0.8 | 0.9 |

---

## Step 6: Deploy Configuration to Poller

After adding hosts and services:

1. Navigate to **Configuration > Pollers**
2. Select the poller
3. Click **Export configuration**
4. Check all four options:
   - Generate files
   - Run monitoring engine debug (-v)
   - Move exported files
   - Restart monitoring engine
5. Click **Export**
6. Verify the export completes without errors
7. On the Centreon poller, confirm the core services restarted cleanly:

```bash
sudo systemctl is-active gorgoned
sudo systemctl is-active cbd
sudo systemctl is-active centengine
sudo journalctl -u gorgoned -n 50 --no-pager
sudo journalctl -u cbd -n 50 --no-pager
sudo journalctl -u centengine -n 50 --no-pager
```

Expected result:
- all three services return `active`
- no configuration or syntax errors appear in the recent logs

---

## Step 7: Validate Checks from the Poller

Before relying on the UI state, confirm the poller can execute the same checks that Centreon
will run for the host.

```bash
# Basic SNMP reachability from the poller
snmpget -v2c -c public_ro <target-ip> sysDescr.0
snmpget -v2c -c public_ro <target-ip> sysUpTimeInstance

# Optional: inspect which Linux SNMP plugin commands are installed
find /usr/lib/centreon/plugins -maxdepth 1 -type f | grep centreon
```

If SNMP fails here, the host will stay `PENDING`, `DOWN`, or `UNKNOWN` in the Centreon UI.

---

## Step 8: Trigger the First Checks so the Host Leaves Pending

1. Navigate to **Monitoring > Resources Status**
2. Filter by host name or IP
3. If the host or services still show `PENDING`, use the UI actions to force the first execution:
   - open the host details page
   - choose **Reschedule check** for the host
   - choose **Reschedule check** for all linked services
   - if available in your Centreon version, use **Submit result** only for testing, not normal operations
4. Wait one or two poller cycles
5. The host should move to `UP`
6. All linked services should move from `PENDING` to `OK` within 5 minutes

Command-side confirmation on the poller while waiting:

```bash
sudo journalctl -u centengine -f
```

You should see the host and service checks being scheduled and executed.

If a host shows `DOWN` or services show `UNKNOWN`, see [troubleshooting.md](troubleshooting.md).

---

## Host Naming Convention

Use consistent naming across Ansible inventory and Centreon:

| System | Name format | Example |
|--------|------------|---------|
| Ansible inventory | `<role>-<site>-<number>` | linux-target-01 |
| Centreon host name | Same as Ansible | linux-target-01 |
| Centreon alias | Human-readable | Web Server 01 |

---

## Verification

From the Centreon poller, test SNMP before registering:

```bash
# Test SNMP connectivity (run from poller, not central server)
snmpget -v2c -c public_ro <target-ip> sysDescr.0
snmpwalk -v2c -c public_ro <target-ip> .1.3.6.1.2.1.1

# Check poller can reach target
ping -c 3 <target-ip>
nc -uzv <target-ip> 161

# Check Centreon engine services are healthy
sudo systemctl is-active gorgoned cbd centengine
```

In Centreon UI:
- Host status: UP (green)
- CPU/Memory/Disk/Network services: OK (green)
- No PENDING, UNKNOWN, or UNREACHABLE hosts

If the UI still shows `PENDING` after export and rescheduling, the problem is usually one of:
- the poller was not selected correctly in the host definition
- the poller configuration was not exported after the host was created
- SNMP UDP/161 is blocked between the poller and the target
- the template was applied but services were not created from the template

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [setup-snmp.md](setup-snmp.md) | SNMP agent configuration on targets |
| [setup-firewall.md](setup-firewall.md) | UFW rule for SNMP UDP/161 |
| [troubleshooting.md](troubleshooting.md) | Centreon and SNMP issue diagnosis |
