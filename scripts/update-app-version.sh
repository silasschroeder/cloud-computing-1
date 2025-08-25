#!/bin/bash

# Application Version Update Script
# Usage: ./update-app-version.sh [new_app_version] [master_ip]

set -e

NEW_APP_VERSION="${1:-1.1.0}"
MASTER_IP="${2}"

if [ -z "$MASTER_IP" ]; then
    echo "Error: Master IP is required"
    echo "Usage: ./update-app-version.sh [new_app_version] [master_ip]"
    echo "Example: ./update-app-version.sh 1.1.0 192.168.1.100"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Application Version Update ==="
echo "New Application Version: $NEW_APP_VERSION"
echo "Master IP: $MASTER_IP"
echo "=================================="

cd "$PROJECT_DIR"

# Check if master is accessible
echo "Checking master connectivity..."
if ! ping -c 1 "$MASTER_IP" > /dev/null 2>&1; then
    echo "Warning: Cannot ping master IP $MASTER_IP"
    echo "Continuing anyway..."
fi

# Get current infrastructure version from latest deployment info
CURRENT_INFRA_VERSION=$(ls deployment-*.info 2>/dev/null | head -1 | sed 's/deployment-\(.*\)\.info/\1/' || echo "v1.0.0")

echo "Current Infrastructure Version: $CURRENT_INFRA_VERSION"

# Generate new K8s manifest with updated app version
terraform apply -var="app_version=$NEW_APP_VERSION" -var="infrastructure_version=$CURRENT_INFRA_VERSION" -auto-approve

# Create update script for remote execution
cat > /tmp/update-app.sh <<'EOF'
#!/bin/bash
set -e

NEW_APP_VERSION="$1"
MANIFEST_FILE="$2"

echo "Updating application to version $NEW_APP_VERSION..."

# Apply the new manifest
sudo kubectl apply -f "$MANIFEST_FILE"

# Wait for rollout to complete
echo "Waiting for deployment rollout to complete..."
sudo kubectl rollout status deployment/sample-web-app --timeout=300s

# Verify the deployment
echo "Verifying deployment..."
sudo kubectl get pods -l app=sample-web-app
sudo kubectl get svc sample-web-app-service

echo "Application update completed successfully!"
EOF

# Copy files to master
echo "Copying update script and manifest to master..."
scp -o StrictHostKeyChecking=no /tmp/update-app.sh ubuntu@"$MASTER_IP":/tmp/
scp -o StrictHostKeyChecking=no "k8s-entities-${CURRENT_INFRA_VERSION}.yaml" ubuntu@"$MASTER_IP":/tmp/

# Execute update on master
echo "Executing application update on master..."
ssh -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "chmod +x /tmp/update-app.sh && /tmp/update-app.sh '$NEW_APP_VERSION' '/tmp/k8s-entities-${CURRENT_INFRA_VERSION}.yaml'"

# Update deployment info
cat > "deployment-${CURRENT_INFRA_VERSION}.info" <<EOF
Infrastructure Version: $CURRENT_INFRA_VERSION
Application Version: $NEW_APP_VERSION
Master IP: $MASTER_IP
Last Update: $(date)
K8s Manifest: k8s-entities-${CURRENT_INFRA_VERSION}.yaml
EOF

echo "Application version updated successfully to $NEW_APP_VERSION!"
echo "Deployment info updated in deployment-${CURRENT_INFRA_VERSION}.info"

# Clean up
rm -f /tmp/update-app.sh