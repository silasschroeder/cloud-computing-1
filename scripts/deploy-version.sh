#!/bin/bash

# Infrastructure Version Management Script
# Usage: ./deploy-version.sh [infrastructure_version] [app_version] [action]
# Actions: plan, apply, destroy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
INFRASTRUCTURE_VERSION="${1:-v1.0.0}"
APP_VERSION="${2:-1.0.0}"
ACTION="${3:-plan}"

echo "=== Infrastructure and Application Version Management ==="
echo "Infrastructure Version: $INFRASTRUCTURE_VERSION"
echo "Application Version: $APP_VERSION"
echo "Action: $ACTION"
echo "============================================="

cd "$PROJECT_DIR"

# Create variables file for this deployment
cat > terraform.tfvars <<EOF
infrastructure_version = "$INFRASTRUCTURE_VERSION"
app_version = "$APP_VERSION"
worker_count = 2
app_replicas = 3
min_replicas = 1
max_replicas = 10
EOF

echo "Generated terraform.tfvars:"
cat terraform.tfvars
echo ""

case "$ACTION" in
    "plan")
        echo "Planning infrastructure deployment..."
        terraform plan -var-file=terraform.tfvars
        ;;
    "apply")
        echo "Applying infrastructure deployment..."
        terraform apply -var-file=terraform.tfvars -auto-approve
        
        # Wait for deployment to complete
        echo "Waiting for infrastructure to be ready..."
        sleep 30
        
        # Get the master IP
        MASTER_IP=$(terraform output -raw master_ip)
        echo "Master IP: $MASTER_IP"
        
        # Save deployment info
        cat > "deployment-${INFRASTRUCTURE_VERSION}.info" <<EOF
Infrastructure Version: $INFRASTRUCTURE_VERSION
Application Version: $APP_VERSION
Master IP: $MASTER_IP
Deployment Time: $(date)
K8s Manifest: k8s-entities-${INFRASTRUCTURE_VERSION}.yaml
EOF
        
        echo "Deployment information saved to deployment-${INFRASTRUCTURE_VERSION}.info"
        ;;
    "destroy")
        echo "Destroying infrastructure deployment..."
        terraform destroy -var-file=terraform.tfvars -auto-approve
        
        # Clean up deployment info
        rm -f "deployment-${INFRASTRUCTURE_VERSION}.info"
        rm -f "k8s-entities-${INFRASTRUCTURE_VERSION}.yaml"
        ;;
    *)
        echo "Invalid action: $ACTION"
        echo "Valid actions: plan, apply, destroy"
        exit 1
        ;;
esac

echo "Operation completed successfully!"