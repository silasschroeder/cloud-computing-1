#!/bin/bash
set -e # EXIT ON ERROR

# K3S INSTALLATION
sudo ufw disable # https://docs.k3s.io/installation/requirements?os=debian
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" K3S_TOKEN=12345 K3S_KUBECONFIG_MODE="644" sh -s - # https://docs.k3s.io/installation/configuration

# NFS SERVER INSTALLATION
export MASTER_IP=$(ip -o -4 addr show dev ens3 | awk '{print $4}' | cut -d/ -f1)

sleep 20 # WAIT FOR WORKERS TO CONNECT
# IF THE k8s-entities.yaml IS APPLIED BEFORE THE WORKERS ARE CONNECTED, THE PODS WILL STAY ON THE MASTER NODE

# NFS SERVER SETUP
sudo apt update
sudo apt install nfs-kernel-server -y
sudo mkdir -p /mnt/data # CREATE MOUNT
sudo chown nobody:nogroup /mnt/data
sudo chmod 777 /mnt/data # SET PERMISSIONS
echo "/mnt/data *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports # EXPORT FOLDER
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
sudo systemctl enable nfs-kernel-server

# INSTALL HELM
wget https://get.helm.sh/helm-v3.18.3-linux-amd64.tar.gz
tar xzf helm-v3.18.3-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/sbin
rm -rf linux-amd64
rm helm-v3.18.3-linux-amd64.tar.gz

# NFS CLIENT SETUP ON MASTER
wget https://raw.githubusercontent.com/silasschroeder/files/main/k8s-entities.yaml
envsubst < k8s-entities.yaml > bucket.yaml && mv bucket.yaml k8s-entities.yaml # REPLACE ${MASTER_IP} IN k8s-entities.yaml
kubectl apply -f k8s-entities.yaml

# ADD PROMETHEUS
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# # CONFIG HELM ACCESS
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
source ~/.bashrc

helm install prometheus prometheus-community/prometheus