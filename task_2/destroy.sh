#!/bin/bash

# Load OpenStack environment
export OS_AUTH_URL="https://stack.dhbw.cloud:5000"
export OS_USERNAME="pfisterer-cloud-lecture"
export OS_PASSWORD="ss2025"
export OS_PROJECT_ID="6c1ae45e04f24dc695d6f526fce253c6"
export OS_USER_DOMAIN_NAME="default"

# Destroy infrastructure
echo "Starting infrastructure destruction..."

# Clean up any existing SSH known_hosts backup to prevent conflicts
if [ -f ~/.ssh/known_hosts.old ]; then
    rm -f ~/.ssh/known_hosts.old
    echo "Cleaned up existing SSH known_hosts backup"
fi

echo "Initializing OpenTofu..."
tofu init -upgrade
echo "Destroying infrastructure with OpenTofu..."
tofu destroy -auto-approve

# Clean up inventory file
if [ -f "openstack-inventory.txt" ]; then
    echo "Cleaning up inventory file..."
    rm -f openstack-inventory.txt
fi

echo "Infrastructure destruction completed!"