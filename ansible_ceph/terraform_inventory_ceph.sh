#!/bin/bash
# terraform_inventory_ceph.sh - Dynamisches Ansible Inventory für Ceph (Bash-Version)

TF_DIR="$(dirname "$(dirname "$0")")"
TF_OUTPUT=$(cd "$TF_DIR" && terraform output -json)
ALL_IPS=($(echo "$TF_OUTPUT" | jq -r '.all_private_ips.value[]'))

# JSON-Ausgabe erzeugen
printf '{\n'
printf '  "ceph-nodes": { "hosts": ['
for ip in "${ALL_IPS[@]}"; do printf '"%s",' "$ip"; done | sed 's/,$//'
printf '] },\n'
printf '  "_meta": {\n    "hostvars": {'
for ip in "${ALL_IPS[@]}"; do printf '"%s": {"ansible_user": "ubuntu", "ansible_ssh_private_key_file": "~/.ssh/id_rsa"},' "$ip"; done | sed 's/,$//'
printf '}\n  }\n'
printf '}\n'
