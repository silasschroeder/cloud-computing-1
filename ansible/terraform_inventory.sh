#!/bin/bash
# terraform_inventory.sh - Dynamisches Ansible Inventory aus Terraform-Output (Bash-Version)


# Verzeichnis der Terraform-Konfiguration (anpassen, falls nötig)
TF_DIR="$(dirname "$(dirname "$0")")"
TF_OUTPUT=$(cd "$TF_DIR" && terraform output -json)
ALL_IPS=($(echo "$TF_OUTPUT" | jq -r '.all_private_ips.value[]'))
MASTER_IP=${ALL_IPS[0]}
WORKER_IPS=("${ALL_IPS[@]:1}")

# JSON-Ausgabe erzeugen
printf '{\n'
printf '  "master": { "hosts": ["%s"] },\n' "$MASTER_IP"
printf '  "worker": { "hosts": ['
for ip in "${WORKER_IPS[@]}"; do printf '"%s",' "$ip"; done | sed 's/,$//'
printf '] },\n'
printf '  "all": { "children": ["master", "worker"] },\n'
printf '  "_meta": {\n    "hostvars": {'
for ip in "${ALL_IPS[@]}"; do printf '"%s": {"ansible_user": "ubuntu", "ansible_ssh_private_key_file": "~/.ssh/id_rsa"},' "$ip"; done | sed 's/,$//'
printf '}\n  }\n'
printf '}\n'
