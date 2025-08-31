#!/bin/bash
set -e  # Exit immediately if any command exits with a non-zero status

# -----------------------------------------------------------------------------
# Purpose:
# - Join this node to an existing K3s cluster as a worker (agent).
# - Install NFS client utilities so the node can mount NFS shares from the master.
# -----------------------------------------------------------------------------

# Join the K3s cluster as an agent.
# - K3S_URL: points to the master's Kubernetes API (default port 6443).
# - K3S_TOKEN: shared token that authorizes this worker to join (use a strong secret in production).
# Reference: https://docs.k3s.io/installation/configuration
curl -sfL https://get.k3s.io | K3S_URL="https://${master_ip}:6443" K3S_TOKEN=12345 sh -s -

# Install NFS client tools to enable mounting exports from the master (e.g., /mnt/data).
sudo apt update
sudo apt install nfs-common -y