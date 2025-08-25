#!/bin/bash

# Infrastructure Rollback Script
# Usage: ./rollback.sh [target_version]

set -e

TARGET_VERSION="${1}"

if [ -z "$TARGET_VERSION" ]; then
    echo "Error: Target version is required"
    echo "Usage: ./rollback.sh [target_version]"
    echo "Available versions:"
    ls deployment-*.info 2>/dev/null | sed 's/deployment-\(.*\)\.info/  \1/' || echo "  No deployments found"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Infrastructure Rollback ==="
echo "Target Version: $TARGET_VERSION"
echo "==============================="

cd "$PROJECT_DIR"

# Check if target version deployment info exists
if [ ! -f "deployment-${TARGET_VERSION}.info" ]; then
    echo "Error: No deployment info found for version $TARGET_VERSION"
    echo "Available versions:"
    ls deployment-*.info 2>/dev/null | sed 's/deployment-\(.*\)\.info/  \1/' || echo "  No deployments found"
    exit 1
fi

# Read deployment info
echo "Reading deployment information for version $TARGET_VERSION..."
cat "deployment-${TARGET_VERSION}.info"
echo ""

# Extract app version from deployment info
APP_VERSION=$(grep "Application Version:" "deployment-${TARGET_VERSION}.info" | cut -d' ' -f3)

echo "Rolling back to:"
echo "  Infrastructure Version: $TARGET_VERSION"
echo "  Application Version: $APP_VERSION"
echo ""

# Ask for confirmation
read -p "Are you sure you want to rollback to version $TARGET_VERSION? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Rollback cancelled."
    exit 0
fi

# Destroy current infrastructure first
echo "Destroying current infrastructure..."
terraform destroy -auto-approve || echo "No current infrastructure to destroy"

# Apply target version
echo "Deploying target version $TARGET_VERSION..."
cat > terraform.tfvars <<EOF
infrastructure_version = "$TARGET_VERSION"
app_version = "$APP_VERSION"
worker_count = 2
app_replicas = 3
min_replicas = 1
max_replicas = 10
EOF

terraform apply -var-file=terraform.tfvars -auto-approve

# Get the new master IP
MASTER_IP=$(terraform output -raw master_ip)

# Update deployment info with rollback timestamp
cat >> "deployment-${TARGET_VERSION}.info" <<EOF
Rollback Performed: $(date)
New Master IP: $MASTER_IP
EOF

echo ""
echo "=== Rollback Completed Successfully ==="
echo "Infrastructure Version: $TARGET_VERSION"
echo "Application Version: $APP_VERSION"
echo "Master IP: $MASTER_IP"
echo "======================================="