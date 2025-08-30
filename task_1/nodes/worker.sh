#!/bin/bash
set -e # EXIT ON ERROR

# JOIN K3S CLUSTER 
curl -sfL https://get.k3s.io | K3S_URL="https://${master_ip}:6443" K3S_TOKEN=12345 sh -s - # https://docs.k3s.io/installation/configuration

sudo apt update
sudo apt install nfs-common -y