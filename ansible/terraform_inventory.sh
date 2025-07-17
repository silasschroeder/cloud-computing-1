#!/usr/bin/env bash
# terraform_inventory.sh - Dynamisches Ansible Inventory aus Terraform-Output (Bash-Version)


# Verzeichnis der Terraform-Konfiguration (anpassen, falls nötig)
TF_DIR="$(dirname "$(dirname "$0")")"
TF_OUTPUT=$(cd "$TF_DIR" && terraform output -json)
ALL_IPS=($(echo "$TF_OUTPUT" | jq -r '.all_private_ips.value[]'))
MASTER_IP=${ALL_IPS[0]}
WORKER_IPS=("${ALL_IPS[@]:1}")

# Hostnamen generieren (ohne assoziative Arrays)
MASTER_HOSTNAME="mjcs2-k8s-master"
WORKER_HOSTNAMES=""
for i in $(seq 0 $((${#WORKER_IPS[@]} - 1))); do
	WORKER_HOSTNAMES="$WORKER_HOSTNAMES mjcs2-k8s-worker-$i"
done

# JSON-Ausgabe erzeugen
printf '{\n'
printf '  "master": { "hosts": ["%s"] },\n' "$MASTER_HOSTNAME"
printf '  "worker": { "hosts": ['
for i in $(seq 0 $((${#WORKER_IPS[@]} - 1))); do
	hn="mjcs2-k8s-worker-$i"
	printf '"%s",' "$hn"
done | sed 's/,$//'
printf '] },\n'
printf '  "all": { "children": ["master", "worker"] },\n'
printf '  "_meta": {\n    "hostvars": {'

# Master hostvars
printf '"%s": {"ansible_host": "%s", "ansible_user": "ubuntu", "ansible_ssh_private_key_file": "~/.ssh/id_rsa"},' "$MASTER_HOSTNAME" "$MASTER_IP"

# Worker hostvars
for i in $(seq 0 $((${#WORKER_IPS[@]} - 1))); do
	hn="mjcs2-k8s-worker-$i"
	ip="${WORKER_IPS[$i]}"
	printf '"%s": {"ansible_host": "%s", "ansible_user": "ubuntu", "ansible_ssh_private_key_file": "~/.ssh/id_rsa"},' "$hn" "$ip"
done | sed 's/,$//'

printf '}\n  }\n'
printf '}\n'
