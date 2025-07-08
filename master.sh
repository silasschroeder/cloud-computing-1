#!/bin/bash
curl -L https://github.com/saltstack/salt-bootstrap/releases/latest/download/bootstrap-salt.sh -o bootstrap-salt.sh
sudo sh bootstrap-salt.sh -M -N # -M for Master, -N to avoid installing Minion
sudo bash -c 'echo "auto_accept: True" >> /etc/salt/master' # Enable auto-accept for Minion keys
sudo mkdir -p /srv/salt/
curl -L https://raw.githubusercontent.com/silasschroeder/files/main/install_packages.sls -o /srv/salt/install_packages.sls # Download .sls file
sudo systemctl restart salt-master # Restart the Salt Master to apply the configuration