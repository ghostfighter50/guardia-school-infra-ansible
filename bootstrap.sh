#!/usr/bin/env bash
# Bootstrap helper for the Ansible controller.
# Prepares local dependencies and prints the recommended execution order.
set -euo pipefail

cd "$(dirname "$0")"

# 1) Ensure Ansible SSH key exists
if [[ ! -f "$HOME/.ssh/ansible_id_ed25519" ]]; then
  echo "[+] Generating Ansible SSH key"
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -N "" -C "ansible@$(hostname)" -f "$HOME/.ssh/ansible_id_ed25519"
fi

# 2) Install required Ansible collections
echo "[+] Installing required Ansible collections"
ansible-galaxy collection install -r requirements.yml

echo
echo "Bootstrap complete. Run playbooks in this order:"
echo "  1) Update inventory/nmap_discovery.yml (subnet/exclusions if needed)"
echo "  2) Update inventory/group_vars/all.yml"
echo "  3) ansible-playbook playbooks/00_service_account.yml -k -K"
echo "  4) ansible-playbook playbooks/01_vault.yml -K"
echo "  5) ansible-playbook -i inventory/hosts.yml -i inventory/nmap_discovery.yml playbooks/02_discover.yml"
echo "  6) ansible-playbook playbooks/03_harden.yml"

