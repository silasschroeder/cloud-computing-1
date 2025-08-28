#!/bin/bash

# Load OpenStack environment
export OS_AUTH_URL="https://stack.dhbw.cloud:5000"
export OS_USERNAME="pfisterer-cloud-lecture"
export OS_PASSWORD="ss2025"
export OS_PROJECT_ID="6c1ae45e04f24dc695d6f526fce253c6"
export OS_USER_DOMAIN_NAME="default"

echo "🔄 Git-based Rollback System"
echo "============================"

# Show available version tags
echo "📋 Available versions:"
TAGS=$(git tag --list "v*" --sort=-version:refname 2>/dev/null)
if [ -n "$TAGS" ]; then
    echo "$TAGS" | head -10
    TAG_COUNT=$(echo "$TAGS" | wc -l)
    if [ "$TAG_COUNT" -gt 10 ]; then
        echo "... and $((TAG_COUNT - 10)) more versions"
    fi
else
    echo "No version tags found"
    exit 1
fi

echo ""

# Get current status
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "📍 Current branch: $CURRENT_BRANCH"

# Get version to rollback to
echo ""
read -p "Enter version tag to rollback to (e.g., v1.0.0) or 'previous' for the last version: " ROLLBACK_VERSION

if [ "$ROLLBACK_VERSION" = "previous" ]; then
    # Get the most recent version tag
    ROLLBACK_VERSION=$(git tag --list "v*" --sort=-version:refname | head -1)
    if [ -z "$ROLLBACK_VERSION" ]; then
        echo "❌ Error: No previous version found"
        exit 1
    fi
    echo "🏷️  Selected previous version: $ROLLBACK_VERSION"
fi

# Validate version exists
if ! git tag --list | grep -q "^${ROLLBACK_VERSION}$"; then
    echo "❌ Error: Version tag $ROLLBACK_VERSION not found"
    exit 1
fi

echo ""
echo "🚨 WARNING: This will:"
echo "   1. Destroy current infrastructure"
echo "   2. Switch to version $ROLLBACK_VERSION"
echo "   3. Redeploy infrastructure with that version"
echo ""
read -p "Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Rollback cancelled"
    exit 0
fi

# Destroy current infrastructure
echo ""
echo "🏗️  Destroying current infrastructure..."
terraform destroy -auto-approve

# Switch to the rollback version
echo ""
echo "🔄 Switching to version $ROLLBACK_VERSION..."

# Create a rollback branch name
ROLLBACK_BRANCH="rollback-to-$(echo $ROLLBACK_VERSION | sed 's/v//')-$(date +%Y%m%d-%H%M%S)"

# Check out the tag and create a new branch
git checkout -b "$ROLLBACK_BRANCH" "$ROLLBACK_VERSION"

if [ $? -ne 0 ]; then
    echo "❌ Error: Failed to checkout version $ROLLBACK_VERSION"
    exit 1
fi

echo "✅ Switched to version $ROLLBACK_VERSION on branch $ROLLBACK_BRANCH"

# Deploy the rollback version
echo ""
echo "🚀 Deploying version $ROLLBACK_VERSION..."

# Check if app folder exists (required for ConfigMap generation)
if [ ! -d "app" ]; then
    echo "❌ Error: app/ folder not found in version $ROLLBACK_VERSION"
    echo "This version may be incompatible with the current deployment system."
    exit 1
fi

# Validate app structure
if [ ! -f "app/package.json" ] || [ ! -f "app/server.js" ]; then
    echo "❌ Error: Required app files (package.json, server.js) not found in app/"
    echo "This version may be incompatible with the current deployment system."
    exit 1
fi

terraform init
terraform apply -auto-approve

# Get master IP and deploy application if k8s manifest exists
if [ -f "k8s-app.yaml" ]; then
    echo ""
    echo "📱 Deploying application..."
    
    # Verify k8s manifest contains app source
    if ! grep -q "app-source-" k8s-app.yaml; then
        echo "⚠️  Warning: k8s-app.yaml doesn't contain app source ConfigMap"
        echo "This may be an older version format. Application deployment may fail."
    fi
    
    # Get master IP from Terraform output
    MASTER_IP=$(grep -A 3 "mjcs2-k8s-master" terraform.tfstate | grep "access_ip_v4" | cut -d'"' -f4)
    
    if [ -n "$MASTER_IP" ]; then
        echo "Master IP: $MASTER_IP"
        echo "Waiting for infrastructure to be ready..."
        sleep 120
        
        # Update k8s manifest with master IP
        cp k8s-app.yaml k8s-app-deploy.yaml
        sed -i "s/MASTER_IP_PLACEHOLDER/$MASTER_IP/g" k8s-app-deploy.yaml
        
        # Copy and deploy
        scp -o StrictHostKeyChecking=no k8s-app-deploy.yaml ubuntu@$MASTER_IP:~/k8s-app.yaml
        
        ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP << 'ENDSSH'
            # Wait for cloud-init and setup cluster
            sudo cloud-init status --wait
            sudo salt 'mjcs2-k8s-master' state.apply master_pre-worker-setup
            
            # Configure workers
            MASTER_IP=$(cat ~/master_ip.txt)
            TOKEN=$(cat ~/master_token.txt)
            sudo sed -i "s/<master_ip>/$MASTER_IP/g" /srv/salt/worker_setup.sls
            sudo sed -i "s/<k8s_token>/$TOKEN/g" /srv/salt/worker_setup.sls
            sudo salt 'mjcs2-k8s-worker*' state.apply worker_setup
            
            # Wait and deploy
            sleep 60
            sudo kubectl apply -f k8s-app.yaml
            
            echo "Application deployed!"
            sudo kubectl get pods
            sudo kubectl get services
ENDSSH
        
        # Clean up temp file
        rm -f k8s-app-deploy.yaml
    else
        echo "⚠️  Could not extract master IP. Manual application deployment required."
    fi
fi

# Create rollback commit
git add .
git commit -m "Rollback to version $ROLLBACK_VERSION - $(date)"

echo ""
echo "✅ Successfully rolled back to version $ROLLBACK_VERSION"
echo "📍 Current branch: $ROLLBACK_BRANCH"
echo "🏷️  Version: $ROLLBACK_VERSION"

if [ -n "$MASTER_IP" ]; then
    echo "🌐 Master IP: $MASTER_IP"
    
    # Try to get service port
    SERVICE_PORT=$(ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo kubectl get service simple-counter-service -o jsonpath='{.spec.ports[0].nodePort}'" 2>/dev/null || echo "")
    if [ -n "$SERVICE_PORT" ]; then
        echo "🔗 Application URL: http://$MASTER_IP:$SERVICE_PORT"
    fi
fi

echo ""
echo "📋 Useful commands:"
echo "   SSH to master: ssh ubuntu@$MASTER_IP"
echo "   Check pods: ssh ubuntu@$MASTER_IP 'sudo kubectl get pods'"
echo "   Check services: ssh ubuntu@$MASTER_IP 'sudo kubectl get services'"
echo "   View Git log: git log --oneline"