#!/bin/bash
set -e

# Salt-Installation
mkdir -p /etc/apt/keyrings
curl -fsSL https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public | tee /etc/apt/keyrings/salt-archive-keyring.pgp
curl -fsSL https://github.com/saltstack/salt-install-guide/releases/latest/download/salt.sources | tee /etc/apt/sources.list.d/salt.sources

echo 'Package: salt-*
Pin: version 3006.*
Pin-Priority: 1001' | tee /etc/apt/preferences.d/salt-pin-1001

apt update
apt install -y salt-minion

mkdir -p /etc/salt/minion.d/
echo "master: ${master_ip}" | sudo tee /etc/salt/minion.d/master.conf

systemctl restart salt-minion
