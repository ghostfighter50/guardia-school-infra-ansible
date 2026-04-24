# Troubleshooting

Diagnosis and resolution for common issues across all components.

---

## Quick Diagnostics

```bash
# Test basic network connectivity
ping <target-ip>

# Test SSH port
nc -zv <target-ip> 2222

# Test Vault
curl -s http://127.0.0.1:8200/v1/sys/health | python -m json.tool

# Test Ansible connectivity
ansible linux_targets -m ping

# Run with verbose output
ansible linux_targets -m ping -vvv
```

---

## SSH Issues

### Connection refused on port 2222

**Symptom**: `ssh: connect to host <target-ip> port 2222: Connection refused`

**Diagnosis**:
```bash
# Try port 22 (pre-hardening)
ssh admin@<target-ip>

# Check if sshd is running
ssh admin@<target-ip> 'sudo systemctl is-active sshd'

# Check if sshd is listening on 2222
ssh admin@<target-ip> 'sudo ss -tuln | grep 2222'

# Validate sshd config
ssh admin@<target-ip> 'sudo sshd -t'
```

**Resolution**:
```bash
# Re-run SSH hardening
ansible-playbook playbooks/03_harden.yml --tags ssh

# Or manually start sshd on target
ssh admin@<target-ip> 'sudo systemctl start sshd'
```

---

### Permission denied (publickey)

**Symptom**: `Permission denied (publickey).`

**Diagnosis**:
```bash
# Test with verbose SSH
ssh -vvv -p 2222 -i ~/.ssh/ansible_id_ed25519 ansible@<target-ip>

# Check if ansible user exists
ssh admin@<target-ip> 'id ansible'

# Check authorized_keys
ssh admin@<target-ip> 'sudo cat /home/ansible/.ssh/authorized_keys'

# Check file permissions
ssh admin@<target-ip> 'sudo stat /home/ansible/.ssh /home/ansible/.ssh/authorized_keys'
```

**Resolution**:
```bash
# Re-run service account bootstrap
ansible-playbook playbooks/00_service_account.yml -k -K

# Or fix permissions manually
ssh admin@<target-ip> 'sudo chmod 700 /home/ansible/.ssh && sudo chmod 600 /home/ansible/.ssh/authorized_keys'
```

---

### TOTP code rejected

**Symptom**: Login prompt accepts key but rejects the 6-digit code.

**Diagnosis**:
```bash
# Check time sync on target
ssh -p 2222 admin@<target-ip> 'timedatectl status'

# Check local time
date

# Confirm TOTP secret file exists
ssh -p 2222 admin@<target-ip> 'stat ~/.google_authenticator'

# Confirm PAM is configured
ssh -p 2222 admin@<target-ip> 'sudo grep pam_google_authenticator /etc/pam.d/sshd'
```

**Resolution**:
```bash
# Fix time sync on target
ansible linux_targets -m command -a "systemctl restart systemd-timesyncd" -b

# If TOTP secret is missing or corrupt, regenerate
ansible-playbook playbooks/03_harden.yml --tags ssh --limit <hostname>
# Note: this generates a NEW secret - re-enroll in your authenticator app
```

---

## Vault Issues

### Vault connection refused

**Symptom**: `Failed to connect to Vault at http://127.0.0.1:8200: connection refused`

**Diagnosis**:
```bash
sudo systemctl status vault
sudo ss -tuln | grep 8200
sudo journalctl -u vault --since "10 minutes ago"
```

**Resolution**:
```bash
sudo systemctl start vault
# Vault may be sealed after start - unseal it
export VAULT_ADDR=http://127.0.0.1:8200
vault operator unseal <shard1>
vault operator unseal <shard2>
vault operator unseal <shard3>
```

---

### Vault is sealed

**Symptom**: `Error making API request: 503 Service Unavailable`

**Diagnosis**:
```bash
export VAULT_ADDR=http://127.0.0.1:8200
vault status | grep Sealed
```

**Resolution**:
```bash
# Retrieve unseal shards from /root/vault_init.json
sudo cat /root/vault_init.json

vault operator unseal <shard1>
vault operator unseal <shard2>
vault operator unseal <shard3>
vault status
```

---

### Secret not found in Vault

**Symptom**: `No value found at secret/data/hosts/<hostname>/...`

**Diagnosis**:
```bash
export VAULT_ADDR=http://127.0.0.1:8200
vault kv list secret/hosts/
vault kv list secret/hosts/<hostname>/
```

**Resolution**:
```bash
# Re-run the role that seeds this secret
# For admin 2FA:
ansible-playbook playbooks/03_harden.yml --tags ssh --limit <hostname>
# For managed user:
ansible-playbook playbooks/03_harden.yml --tags users --limit <hostname>
```

---

## Firewall Issues

### Connection times out (not refused)

**Symptom**: `ssh: connect to host <target-ip> port 2222: Operation timed out`

**Diagnosis**:
```bash
# Check UFW status - connect temporarily on port 22 first
ssh admin@<target-ip> 'sudo ufw status verbose'

# Check if port 2222 is allowed
ssh admin@<target-ip> 'sudo ufw status | grep 2222'
```

**Resolution**:
```bash
# Re-apply firewall rules
ansible-playbook playbooks/03_harden.yml --tags firewall

# Or manually allow SSH (as a temporary measure)
ssh admin@<target-ip> 'sudo ufw allow 2222/tcp && sudo ufw enable'
```

---

## SNMP Issues

### snmpget returns no response

**Symptom**: `Timeout: No Response from <target-ip>`

**Diagnosis**:
```bash
# Check snmpd is running
ansible linux_targets -m command -a "systemctl is-active snmpd" -b

# Check snmpd is listening
ansible linux_targets -m command -a "ss -uln | grep 161" -b

# Check UFW allows SNMP from your monitoring source
ssh admin@<target-ip> 'sudo ufw status | grep 161'
```

**Resolution**:
```bash
# Re-run SNMP role
ansible-playbook playbooks/03_harden.yml --tags snmp

# Check community string matches what you are querying with
grep snmp_community inventory/group_vars/all.yml
```

---

## Centreon Issues

### Host not detected by poller

**Symptom**: Host shows as unreachable in Centreon after registration.

**Diagnosis**:
- Check network path from poller to target on UDP/161
- Verify community string in Centreon matches `snmp_community` in group_vars
- Verify `snmp_allowed_source` in group_vars matches the poller IP, not the central server IP

**Resolution**:
```bash
# Test SNMP from the poller machine (not central server)
snmpget -v2c -c public_ro <target-ip> sysDescr.0

# Update snmp_allowed_source if poller IP changed
vim inventory/group_vars/all.yml
ansible-playbook playbooks/03_harden.yml --tags snmp
```

---

### Host template not applying services

**Symptom**: Host registered in Centreon but no services appear.

**Resolution**:
- In Centreon: Configuration > Hosts > select host > check that the correct host template is applied
- Click Apply Configuration and deploy to the poller
- See [setup-centreon.md](setup-centreon.md) for template configuration details

---

## Ansible Issues

### Hosts not in inventory

**Symptom**: `Could not match supplied host pattern`

**Diagnosis**:
```bash
ansible-inventory --list
ansible-inventory --graph
```

**Resolution**: Check `inventory/hosts.yml` syntax and host entries.

---

### Task fails with become error

**Symptom**: `sudo: a password is required`

**Diagnosis**:
```bash
# Test sudo without password
ssh -i ~/.ssh/ansible_id_ed25519 ansible@<target-ip> "sudo whoami"
```

**Resolution**:
```bash
# Re-run service account bootstrap
ansible-playbook playbooks/00_service_account.yml -k
```

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [setup-vault.md](setup-vault.md) | Vault setup and unsealing |
| [setup-ssh.md](setup-ssh.md) | SSH configuration details |
| [setup-2fa.md](setup-2fa.md) | TOTP configuration |
| [setup-firewall.md](setup-firewall.md) | UFW firewall rules |
| [setup-snmp.md](setup-snmp.md) | SNMP agent configuration |
| [setup-centreon.md](setup-centreon.md) | Centreon integration |
| [validation.md](validation.md) | Full validation checklist |
