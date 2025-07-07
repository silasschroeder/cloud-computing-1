#!/bin/bash
MASTER_IP=$(cat k8s_master_ip.txt)
curl -L https://github.com/saltstack/salt-bootstrap/releases/latest/download/bootstrap-salt.sh -o /tmp/bootstrap-salt.sh
chmod +x /tmp/bootstrap-salt.sh
sudo /tmp/bootstrap-salt.sh -A -i $MASTER_IP