# Deployment Validation

Structured checklist to validate each phase of the deployment. Work through each section
in order after completing the corresponding installation steps.

---

## Phase 0: Pre-deployment

- [ ] Ansible version is 2.12 or newer
	```bash
	ansible --version | head -1
	```
- [ ] Required collections are installed
	```bash
	ansible-galaxy collection list | grep -E "ansible.posix|community.general|community.hashi_vault"
	```
- [ ] ED25519 SSH key exists
	```bash
	ls -la ~/.ssh/ansible_id_ed25519 ~/.ssh/ansible_id_ed25519.pub
	```
- [ ] `ansible.cfg` points to the correct inventory and key
	```bash
	grep -E "inventory|private_key_file" ansible.cfg
	```
- [ ] `inventory/hosts.yml` contains the intended target hosts
	```bash
	ansible-inventory --graph
	```
- [ ] `snmp_allowed_source` is set to the real poller IP, not `127.0.0.1`
	```bash
	grep snmp_allowed_source inventory/group_vars/all.yml
	```

---

## Phase 1: Service Account Bootstrap

- [ ] Playbook completed without errors
	```bash
	ansible-playbook playbooks/00_service_account.yml -k -K
	```
- [ ] `ansible` user exists on all targets
	```bash
	ansible linux_targets -m command -a "id ansible" -k
	```
- [ ] SSH key authentication works
	```bash
	ssh -i ~/.ssh/ansible_id_ed25519 ansible@<target-ip> whoami
	```
- [ ] Passwordless sudo works for the `ansible` user
	```bash
	ssh -i ~/.ssh/ansible_id_ed25519 ansible@<target-ip> "sudo whoami"
	```

---

## Phase 2: Vault

- [ ] Playbook completed without errors
	```bash
	ansible-playbook playbooks/01_vault.yml -K
	```
- [ ] Vault service is active
	```bash
	sudo systemctl is-active vault
	```
- [ ] Vault is initialized and unsealed
	```bash
	export VAULT_ADDR=http://127.0.0.1:8200
	vault status | grep -E "Initialized|Sealed"
	```
- [ ] KV v2 is mounted at `secret/`
	```bash
	vault secrets list | grep "^secret/"
	```
- [ ] Bootstrap secrets exist
	```bash
	vault kv list secret/infra/
	```
- [ ] `/root/vault_init.json` is mode `0600`
	```bash
	sudo stat /root/vault_init.json | grep Access
	```

---

## Phase 3: SSH Hardening

- [ ] Playbook completed without errors
	```bash
	ansible-playbook playbooks/03_harden.yml --tags ssh
	```
- [ ] sshd is listening on port `2222`
	```bash
	ansible linux_targets -m command -a "ss -tuln | grep 2222" -b
	```
- [ ] Drop-in config is deployed
	```bash
	ansible linux_targets -m command -a "cat /etc/ssh/sshd_config.d/99-hardening.conf" -b
	```
- [ ] PAM TOTP is configured
	```bash
	ansible linux_targets -m command -a "grep pam_google_authenticator /etc/pam.d/sshd" -b
	```
- [ ] Admin TOTP secret is present in Vault
	```bash
	vault kv get secret/hosts/<hostname>/admin_2fa
	```

---

## Phase 4: Firewall

- [ ] Playbook completed without errors
	```bash
	ansible-playbook playbooks/03_harden.yml --tags firewall
	```
- [ ] UFW is active on all targets
	```bash
	ansible linux_targets -m command -a "ufw status | head -1" -b
	```
- [ ] SSH port `2222` is allowed
	```bash
	ansible linux_targets -m command -a "ufw status | grep 2222" -b
	```
- [ ] SNMP port `161/udp` is allowed for the poller
	```bash
	ansible linux_targets -m command -a "ufw status | grep 161" -b
	```

---

## Phase 5: SNMP Agent

- [ ] Playbook completed without errors
	```bash
	ansible-playbook playbooks/03_harden.yml --tags snmp
	```
- [ ] `snmpd` is active on all targets
	```bash
	ansible linux_targets -m command -a "systemctl is-active snmpd" -b
	```
- [ ] `snmpd` is listening on UDP/161
	```bash
	ansible linux_targets -m command -a "ss -uln | grep 161" -b
	```
- [ ] Local SNMP query succeeds
	```bash
	ansible linux_targets -m command -a "snmpget -v2c -c public_ro 127.0.0.1 sysDescr.0" -b
	```

---

## Phase 6: Managed User

- [ ] Playbook completed without errors
	```bash
	ansible-playbook playbooks/03_harden.yml --tags users
	```
- [ ] `deploy` user exists on all targets
	```bash
	ansible linux_targets -m command -a "id deploy" -b
	```
- [ ] `deploy` password is stored in Vault
	```bash
	vault kv get secret/hosts/<hostname>/user
	```
- [ ] `deploy` TOTP secret is stored in Vault
	```bash
	vault kv get secret/hosts/<hostname>/2fa
	```

---

## Phase 7: Centreon Integration

- [ ] Linux SNMP plugin pack is installed in Centreon
- [ ] Host template `OS-Linux-SNMP-custom` exists
	- Navigate: Configuration > Hosts > Templates
- [ ] SNMP macros in the template match the repository configuration
	- `SNMPCOMMUNITY` matches `snmp_community`
	- `SNMPVERSION` = `2c`
- [ ] Poller can query the target before host creation
	```bash
	# Run from the Centreon poller
	snmpget -v2c -c public_ro <target-ip> sysDescr.0
	snmpget -v2c -c public_ro <target-ip> sysUpTimeInstance
	```
- [ ] Each target is registered as a host in Centreon
	- [ ] Host name matches the Ansible inventory hostname
	- [ ] Host IP is correct
	- [ ] Host template `OS-Linux-SNMP-custom` is applied
	- [ ] Correct poller is selected
- [ ] Configuration is exported to the poller
	- Navigate: Configuration > Pollers > Export configuration
- [ ] Poller services are healthy after export
	```bash
	sudo systemctl is-active gorgoned
	sudo systemctl is-active cbd
	sudo systemctl is-active centengine
	```
- [ ] Poller logs show checks executing
	```bash
	sudo journalctl -u centengine -n 50 --no-pager
	```
- [ ] Initial checks have been rescheduled from the UI
	- Navigate: Monitoring > Resources Status > Host details > Reschedule check
	- Reschedule the host and all linked services
- [ ] All hosts show status `UP`
- [ ] All services show status `OK`
- [ ] No host or service remains in `PENDING` after 5 minutes

---

## Final Sign-off

- [ ] All phases above are complete with no open items
- [ ] Vault init file backed up offline
- [ ] Admin TOTP enrolled for all administrators
- [ ] `deploy` user TOTP enrolled
- [ ] Centreon alerts configured

---

## Related Documents

| Document | Purpose |
|----------|---------|
| [installation.md](installation.md) | Deployment steps |
| [setup-centreon.md](setup-centreon.md) | Centreon registration steps |
| [troubleshooting.md](troubleshooting.md) | Resolving failures found during validation |
