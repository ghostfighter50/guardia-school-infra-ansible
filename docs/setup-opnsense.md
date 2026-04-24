# OPNsense Setup

Manual reference for integrating an OPNsense gateway with the current Ansible-managed Linux environment.

---

## Overview

The current repository does not automate OPNsense configuration. OPNsense appears in the sample
inventory as a firewall or gateway reference host, and this document describes the manual steps
needed to keep the perimeter configuration consistent with the Linux hardening roles.

---

## Prerequisites

| Requirement | Notes |
|-------------|-------|
| OPNsense installed | Current examples assume OPNsense reachable at `10.1.90.1` |
| Web UI access | HTTPS access to the OPNsense administrator interface |
| Linux targets inventory defined | See `inventory/hosts.yml` |
| Monitoring source IP known | Needed for SNMP allow rules on Linux targets |

---

## Reference Topology

| Component | Example IP | Purpose |
|-----------|------------|---------|
| OPNsense gateway | `10.1.90.1` | LAN gateway and perimeter filtering |
| Linux target | `10.1.90.10` | Ansible-managed host |
| Ansible controller | local or management LAN | Runs playbooks and Vault |
| Centreon poller | `<poller-ip>` | Queries SNMP on UDP/161 |

---

## Step 1: Verify LAN Interface Addressing

In the OPNsense UI:

1. Navigate to **Interfaces > LAN**
2. Confirm the LAN interface IP matches the network used by `inventory/hosts.yml`
3. Confirm the subnet covers the managed hosts
4. Apply changes if required

Recommended baseline for the sample repository:

| Setting | Value |
|---------|-------|
| LAN address | `10.1.90.1` |
| LAN subnet | `/24` |
| Managed network | `10.1.90.0/24` |

---

## Step 2: Create Helpful Aliases

Navigate to **Firewall > Aliases** and create:

| Alias | Type | Example |
|-------|------|---------|
| `ANSIBLE_TARGETS` | Hosts | `10.1.90.10` |
| `CENTREON_POLLER` | Host | `<poller-ip>` |
| `MGMT_NET` | Network | `10.1.90.0/24` |

These aliases simplify future rule maintenance.

---

## Step 3: Define LAN Rules Consistent with the Repo

The main Linux playbooks already enforce host-local controls using UFW. OPNsense should complement
that with network-level filtering instead of contradicting it.

Recommended LAN-side rules:

| Source | Destination | Protocol | Port | Purpose |
|--------|-------------|----------|------|---------|
| `MGMT_NET` | `ANSIBLE_TARGETS` | TCP | 2222 | SSH after hardening |
| `CENTREON_POLLER` | `ANSIBLE_TARGETS` | UDP | 161 | SNMP polling |
| Controller IP | Vault host | TCP | 8200 | Vault API when not local-only |

In the UI:

1. Navigate to **Firewall > Rules > LAN**
2. Add the required allow rules
3. Keep the default deny behavior for traffic that is not explicitly required
4. Apply changes

---

## Step 4: Optional Port Forwarding

Only create NAT or port forwards if external access is genuinely required. The repository itself
does not require Internet-exposed SSH, SNMP, or Vault.

If you must expose a service:

1. Navigate to **Firewall > NAT > Port Forward**
2. Add the minimum required forward
3. Restrict the source as tightly as possible
4. Add a matching WAN rule only for the required source

---

## Step 5: Verify Routing and Reachability

Use these checks after applying OPNsense changes:

```bash
# From the controller or management workstation
ping <target-ip>
nc -zv <target-ip> 2222

# From the Centreon poller
snmpget -v2c -c public_ro <target-ip> sysDescr.0
```

In the OPNsense UI, also inspect:

1. **Firewall > Log Files > Live View** for blocked traffic
2. **Interfaces > Diagnostics > Ping** to test from the firewall itself
3. **System > Routes > Status** to confirm expected routing

---

## Verification

The integration is considered ready when:

- the controller can reach managed hosts on TCP/2222
- the Centreon poller can query managed hosts on UDP/161
- no unnecessary WAN exposure exists for SSH, SNMP, or Vault
- OPNsense rules do not conflict with the Linux UFW rules described in this repository

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [setup-firewall.md](setup-firewall.md) | Host-local UFW policy on Linux targets |
| [setup-snmp.md](setup-snmp.md) | SNMP agent requirements |
| [setup-centreon.md](setup-centreon.md) | Poller and UI-side Centreon setup |
