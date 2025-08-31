#!/bin/bash
set -e  # Exit immediately if any command exits with a non-zero status

# -----------------------------------------------------------------------------
# Purpose:
# - Provision a K3s master (server) node on Debian/Ubuntu-based systems.
# - Set up an NFS server on the master to share storage with workers.
# - Install Helm (v3) for Helm chart management.
# - Apply a Kubernetes manifest that references the master's IP (via envsubst).
# -----------------------------------------------------------------------------

# K3s installation
# - Disables UFW to avoid firewall conflicts (see K3s requirements).
# - Installs K3s in "server" mode.
# - Sets a fixed K3S_TOKEN for workers to join (demo only; use a strong secret in production).
# - K3S_KUBECONFIG_MODE=644 makes /etc/rancher/k3s/k3s.yaml world-readable for convenience.
sudo ufw disable  # https://docs.k3s.io/installation/requirements?os=debian
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" K3S_TOKEN=12345 K3S_KUBECONFIG_MODE="644" sh -s -  # https://docs.k3s.io/installation/configuration

# Discover the master's primary IPv4 address on interface ens3.
export MASTER_IP=$(ip -o -4 addr show dev ens3 | awk '{print $4}' | cut -d/ -f1)

# Give the cluster some time for worker nodes to join.
# If manifests are applied before workers are ready, pods get scheduled onto the master only.
sleep 20

# -----------------------------------------------------------------------------
# NFS server setup (on the master)
# - Creates and exports /mnt/data to all clients (insecure, demo setup).
# - Grants broad permissions to simplify lab/teaching scenarios.
#   For production, restrict clients and permissions in /etc/exports.
# -----------------------------------------------------------------------------
sudo apt update
sudo apt install nfs-kernel-server -y
sudo mkdir -p /mnt/data                               # Create export directory
sudo chown nobody:nogroup /mnt/data                   # Set ownership to "nobody"
sudo chmod 777 /mnt/data                              # Open permissions (demo-friendly)
# Export rule:
#  - rw: read/write
#  - sync: replies after data is written
#  - no_subtree_check: don't check parent directory permissions
#  - no_root_squash: keep root privileges from clients (unsafe in prod)
echo "/mnt/data *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
sudo exportfs -a                                      # Re-export shares

# Apply changes via service restart and enable on boot
sudo systemctl restart nfs-kernel-server
sudo systemctl enable nfs-kernel-server

# -----------------------------------------------------------------------------
# Install Helm v3
# - Downloads a specific Helm version and puts it on PATH.
# - Adjust the version as needed.
# -----------------------------------------------------------------------------
wget https://get.helm.sh/helm-v3.18.3-linux-amd64.tar.gz
tar xzf helm-v3.18.3-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/sbin              # Move binary into PATH
rm -rf linux-amd64
rm helm-v3.18.3-linux-amd64.tar.gz

# -----------------------------------------------------------------------------
# Kubernetes manifests
# - Download k8s-entities.yaml which contains ${MASTER_IP} placeholders.
# - Substitute ${MASTER_IP} with the detected IP using envsubst, then apply.
#   Note: envsubst is provided by the "gettext-base" package; install if missing.
# - kubectl is included with K3s and available on PATH as "kubectl".
# -----------------------------------------------------------------------------
wget https://raw.githubusercontent.com/silasschroeder/files/main/k8s-entities.yaml
envsubst < k8s-entities.yaml > bucket.yaml && mv bucket.yaml k8s-entities.yaml  # Replace ${MASTER_IP} in file
kubectl apply -f k8s-entities.yaml