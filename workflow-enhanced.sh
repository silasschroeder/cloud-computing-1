#!/bin/bash

# Enhanced Workflow with Versioning Support
# This script demonstrates the complete workflow including versioning and rollback

set -e

echo "=== Enhanced Kubernetes Deployment with Application Versioning ==="
echo ""

# Step 1: Deploy infrastructure with specific versions
echo "Step 1: Deploy Infrastructure and Application"
echo "Choose deployment option:"
echo "1. Deploy v1.0.0 infrastructure with app v1.0.0"
echo "2. Deploy v1.1.0 infrastructure with app v1.1.0"
echo "3. Custom versions"
echo "4. Skip deployment (use existing)"

read -p "Enter choice (1-4): " choice

case $choice in
    1)
        echo "Deploying v1.0.0 infrastructure with app v1.0.0..."
        ./scripts/deploy-version.sh v1.0.0 1.0.0 apply
        INFRA_VERSION="v1.0.0"
        ;;
    2)
        echo "Deploying v1.1.0 infrastructure with app v1.1.0..."
        ./scripts/deploy-version.sh v1.1.0 1.1.0 apply
        INFRA_VERSION="v1.1.0"
        ;;
    3)
        read -p "Enter infrastructure version (e.g., v1.2.0): " infra_ver
        read -p "Enter application version (e.g., 1.2.0): " app_ver
        echo "Deploying $infra_ver infrastructure with app $app_ver..."
        ./scripts/deploy-version.sh "$infra_ver" "$app_ver" apply
        INFRA_VERSION="$infra_ver"
        ;;
    4)
        echo "Using existing deployment..."
        INFRA_VERSION=$(ls deployment-*.info 2>/dev/null | head -1 | sed 's/deployment-\(.*\)\.info/\1/' || echo "v1.0.0")
        echo "Found infrastructure version: $INFRA_VERSION"
        ;;
    *)
        echo "Invalid choice, exiting..."
        exit 1
        ;;
esac

# Get master IP
MASTER_IP=$(terraform output -raw master_ip 2>/dev/null || echo "")

if [ -z "$MASTER_IP" ]; then
    echo "Error: Could not get master IP. Make sure infrastructure is deployed."
    exit 1
fi

echo ""
echo "Infrastructure deployed. Master IP: $MASTER_IP"
echo "Waiting for infrastructure to be ready..."
sleep 60

echo ""
echo "Step 2: Connect to master and check status"
echo "Connecting to master at $MASTER_IP..."

# Check if initialisation is done
echo "Checking if initialization is complete..."
ssh -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "tail -10 /var/log/cloud-init-output.log"

echo ""
echo "Step 3: Check Salt minions"
ssh -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "sudo salt-key -L"

echo ""
echo "Step 4: Configure Kubernetes cluster"
ssh -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "sudo salt 'mjcs2-k8s-master*' state.apply master_pre-worker-setup"

echo ""
echo "Step 5: Get master IP and token for worker configuration"
ssh -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "cat master_ip.txt"
ssh -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "cat master_token.txt"

# Extract IP and token for worker setup
INTERNAL_IP=$(ssh -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "cat master_ip.txt")
K8S_TOKEN=$(ssh -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "cat master_token.txt")

echo "Internal Master IP: $INTERNAL_IP"
echo "K8s Token: $K8S_TOKEN"

echo ""
echo "Step 6: Configure worker nodes"
# Update worker setup with actual values
ssh -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "sudo sed -i 's/<master_ip>/$INTERNAL_IP/g' /srv/salt/worker_setup.sls"
ssh -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "sudo sed -i 's/<k8s_token>/$K8S_TOKEN/g' /srv/salt/worker_setup.sls"

ssh -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "sudo salt 'mjcs2-k8s-worker*' state.apply worker_setup"

echo ""
echo "Step 7: Deploy the versioned application"
# Copy and apply the generated k8s manifest
scp -o StrictHostKeyChecking=no "k8s-entities-${INFRA_VERSION}.yaml" ubuntu@"$MASTER_IP":~/k8s-entities.yaml

ssh -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "sudo kubectl apply -f k8s-entities.yaml"

echo ""
echo "Step 8: Verify application deployment"
ssh -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "sudo kubectl get pods"
ssh -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "sudo kubectl get svc"

echo ""
echo "Step 9: Test application access"
ssh -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "curl -s http://localhost/version || echo 'Application not yet ready'"

echo ""
echo "=== Deployment Complete ==="
echo "Master IP: $MASTER_IP"
echo "Infrastructure Version: $INFRA_VERSION"
echo ""
echo "Next steps you can try:"
echo "1. Update application version:"
echo "   ./scripts/update-app-version.sh 1.2.0 $MASTER_IP"
echo ""
echo "2. Deploy new infrastructure version:"
echo "   ./scripts/deploy-version.sh v1.2.0 1.2.0 apply"
echo ""
echo "3. Rollback to previous version:"
echo "   ./scripts/rollback.sh v1.0.0"
echo ""
echo "4. List all versions:"
echo "   ./scripts/list-versions.sh"
echo ""
echo "5. Test the application:"
echo "   ssh ubuntu@$MASTER_IP"
echo "   curl http://localhost/version"