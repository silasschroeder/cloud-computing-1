#!/bin/bash
curl -L https://github.com/saltstack/salt-bootstrap/releases/latest/download/bootstrap-salt.sh -o bootstrap-salt.sh
sudo sh bootstrap-salt.sh -M -N # -M for Master, -N to avoid installing Minion

# Enable auto-accept for Minion keys
sudo bash -c 'echo "auto_accept: True" >> /etc/salt/master'

# Restart the Salt Master to apply the configuration
sudo systemctl restart salt-master