#!/bin/bash

# Load OpenStack environment
export OS_AUTH_URL="https://stack.dhbw.cloud:5000"
export OS_USERNAME="pfisterer-cloud-lecture"
export OS_PASSWORD="ss2025"
export OS_PROJECT_ID="6c1ae45e04f24dc695d6f526fce253c6"
export OS_USER_DOMAIN_NAME="default"

# Deploy infrastructure
echo "Starting infrastructure deployment..."
terraform init
echo "Planning..."
terraform plan
echo "Applying..."
terraform apply -auto-approve

# Get master IP and deploy app
MASTER_IP=$(openstack server list | grep "mjcs2-k8s-master" | head -1 | awk '{print $8}' | cut -d'=' -f2)
echo "Deploying app to $MASTER_IP..."
echo "Waiting for SSH to be ready..."
sleep 60  # Wait longer for system to be ready

# Wait for SSH to be available
until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$MASTER_IP "echo 'SSH ready'" 2>/dev/null; do
    echo "Waiting for SSH connection..."
    sleep 10
done

echo "SSH ready, deploying app..."
scp -o StrictHostKeyChecking=no k8s-app.yaml ubuntu@$MASTER_IP:~/
ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "kubectl apply -f k8s-app.yaml"
echo ""
echo "🌐 =================================="
echo "🎉 App accessible at: http://$MASTER_IP:30080"
echo "🌐 =================================="