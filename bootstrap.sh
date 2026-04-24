#!/usr/bin/env bash
# Script de mise en route (a executer sur le controller Ansible)
set -euo pipefail

cd "$(dirname "$0")"

# 1) Cle SSH d'Ansible
if [[ ! -f "$HOME/.ssh/ansible_id_ed25519" ]]; then
  echo "[+] Generation de la cle SSH Ansible"
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  ssh-keygen -t ed25519 -N "" -C "ansible@$(hostname)" -f "$HOME/.ssh/ansible_id_ed25519"
fi

# 2) Collections Ansible
echo "[+] Installation des collections"
ansible-galaxy collection install -r requirements.yml

echo
echo "Initialisation terminee. Executez :"
echo "  1) Mettre a jour inventory/hosts.yml"
echo "  2) Mettre a jour inventory/group_vars/all.yml"
echo "  3) ansible-playbook playbooks/00_service_account.yml -k -K"
echo "  4) ansible-playbook playbooks/01_vault.yml -K"
echo "  5) ansible-playbook playbooks/03_harden.yml"

