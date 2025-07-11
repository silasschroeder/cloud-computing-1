#!/bin/bash
set -e # exit on error

# install the Salt Project repository (https://docs.saltproject.io/salt/install-guide/en/latest/topics/install-by-operating-system/linux-deb.html)
mkdir -p /etc/apt/keyrings
curl -fsSL https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public | sudo tee /etc/apt/keyrings/salt-archive-keyring.pgp
curl -fsSL https://github.com/saltstack/salt-install-guide/releases/latest/download/salt.sources | sudo tee /etc/apt/sources.list.d/salt.sources

# Pin the Salt Project repository to a specific version (optional)
echo 'Package: salt-*
Pin: version 3006.*
Pin-Priority: 1001' | sudo tee /etc/apt/preferences.d/salt-pin-1001

sudo apt update
sudo apt-get install -y salt-master salt-minion

# sudo mkdir -p /etc/salt/minion.d
sudo ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d'/' -f1 | sudo tee ~/master_ip.txt
echo "master: $(cat ~/master_ip.txt)" | sudo tee /etc/salt/minion.d/master.conf
sudo bash -c 'echo "auto_accept: True" >> /etc/salt/master.d/auto_accept.conf'

sudo systemctl restart salt-minion
sudo systemctl restart salt-master

# Retrieve files for TASK 3:
sudo mkdir /srv/salt/
curl -sfL https://raw.githubusercontent.com/silasschroeder/files/main/master_pre-worker-setup.sls | sudo tee /srv/salt/master_pre-worker-setup.sls
curl -sfL https://raw.githubusercontent.com/silasschroeder/files/main/master_post-worker-setup.sls | sudo tee /srv/salt/master_post-worker-setup.sls
curl -sfL https://raw.githubusercontent.com/silasschroeder/files/main/worker_setup.sls | sudo tee /srv/salt/worker_setup.sls