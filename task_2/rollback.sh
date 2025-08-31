#!/bin/bash

# Load OpenStack environment
export OS_AUTH_URL="https://stack.dhbw.cloud:5000"
export OS_USERNAME="pfisterer-cloud-lecture"
export OS_PASSWORD="ss2025"
export OS_PROJECT_ID="6c1ae45e04f24dc695d6f526fce253c6"
export OS_USER_DOMAIN_NAME="default"

echo "Git-based Rollback System"
echo "============================"

# Show available version tags
echo "Available versions:"
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
echo "Current branch: $CURRENT_BRANCH"

# Get version to rollback to
echo ""
read -p "Enter version tag to rollback to (e.g., v1.0.0) or 'previous' for the last version: " ROLLBACK_VERSION

if [ "$ROLLBACK_VERSION" = "previous" ]; then
    # Get the most recent version tag
    ROLLBACK_VERSION=$(git tag --list "v*" --sort=-version:refname | head -1)
    if [ -z "$ROLLBACK_VERSION" ]; then
        echo "Error: No previous version found"
        exit 1
    fi
    echo "Selected previous version: $ROLLBACK_VERSION"
fi

# Validate version exists
if ! git tag --list | grep -q "^${ROLLBACK_VERSION}$"; then
    echo "Error: Version tag $ROLLBACK_VERSION not found"
    exit 1
fi

echo ""
echo "WARNING: This will:"
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
echo "Destroying current infrastructure..."
tofu destroy -auto-approve

# Commit any pending changes before switching branches
echo ""
echo "Checking for uncommitted changes..."
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Found uncommitted changes. Committing them before rollback..."
    git add .
    git commit -m "Auto-commit before rollback to $ROLLBACK_VERSION - $(date)"
    echo "Changes committed to current branch: $CURRENT_BRANCH"
else
    echo "No uncommitted changes found"
fi

# Switch to the rollback version
echo ""
echo "Switching to version $ROLLBACK_VERSION..."

# Create a rollback branch name
ROLLBACK_BRANCH="rollback-to-$(echo $ROLLBACK_VERSION | sed 's/v//')-$(date +%Y%m%d-%H%M%S)"

# Check out the tag and create a new branch
git checkout -b "$ROLLBACK_BRANCH" "$ROLLBACK_VERSION"

if [ $? -ne 0 ]; then
    echo "Error: Failed to checkout version $ROLLBACK_VERSION"
    exit 1
fi

echo "Switched to version $ROLLBACK_VERSION on branch $ROLLBACK_BRANCH"

# Deploy the rollback version
echo ""
echo "Deploying version $ROLLBACK_VERSION..."

# Check if k8s-app.yaml exists (required for deployment)
if [ ! -f "k8s-app.yaml" ]; then
    echo "Error: k8s-app.yaml not found in version $ROLLBACK_VERSION"
    echo "This version may be incompatible with the current deployment system."
    exit 1
fi

# Clean up any existing SSH known_hosts backup to prevent conflicts
if [ -f ~/.ssh/known_hosts.old ]; then
    rm -f ~/.ssh/known_hosts.old
    echo "Cleaned up existing SSH known_hosts backup"
fi

tofu init
tofu apply -auto-approve

# Get master IP from OpenTofu inventory or state
echo ""
echo "Deploying application..."

# First try to get IP from the new inventory file
if [ -f "openstack-inventory.txt" ]; then
    MASTER_IP=$(cat openstack-inventory.txt)
    echo "Master IP found in inventory file: $MASTER_IP"
else
    # Force creation of inventory file from current state
    tofu refresh > /dev/null 2>&1
    MASTER_IP=$(tofu output -raw master_ip 2>/dev/null || tofu show -json | jq -r '.values.root_module.resources[] | select(.address=="openstack_compute_instance_v2.master") | .values.network[0].fixed_ip_v4' 2>/dev/null)
    
    # If JSON parsing fails, try grep fallback
    if [ -z "$MASTER_IP" ] || [ "$MASTER_IP" = "null" ]; then
        MASTER_IP=$(grep -A 10 '"address": "openstack_compute_instance_v2.master"' terraform.tfstate | grep '"fixed_ip_v4"' | cut -d'"' -f4 | head -1)
    fi
    
    # Create the inventory file manually if extraction worked
    if [ -n "$MASTER_IP" ] && [[ "$MASTER_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$MASTER_IP" > openstack-inventory.txt
        echo "Created inventory file with IP: $MASTER_IP"
    fi
fi

# Validate IP format (basic check)
if [[ ! "$MASTER_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "Error: Could not extract valid master IP address"
    echo "Please check the Terraform state or enter manually."
    read -p "Enter master IP address: " MASTER_IP
fi

if [ -z "$MASTER_IP" ]; then
    echo "Error: IP address cannot be empty"
    exit 1
fi

echo "Master IP: $MASTER_IP"
echo "Waiting for infrastructure to be ready..."
sleep 120
        
# Check SSH connectivity first
echo "Testing SSH connectivity..."
if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$MASTER_IP "echo 'SSH connection successful'" 2>/dev/null; then
    echo "SSH connection established"
else
    echo "SSH connection failed. Possible causes:"
    echo "   - Infrastructure still booting (try waiting longer)"
    echo "   - SSH key not properly configured"
    echo "   - Firewall blocking SSH access"
    echo "Skipping application deployment due to SSH issues"
    echo "   Manual deployment may be required later"
    exit 1
fi

# Copy k8s manifest and deploy
echo "Copying Kubernetes manifests..."
scp -o StrictHostKeyChecking=no k8s-app.yaml ubuntu@$MASTER_IP:~/

echo "Deploying application..."
ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP << 'ENDSSH'
    # Wait for cloud-init
    sudo cloud-init status --wait
    
    # Wait for Salt services
    sleep 30
    
    # Install K3s directly if not present
    if ! command -v kubectl >/dev/null 2>&1; then
        curl -sfL https://get.k3s.io | sudo INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 --disable traefik" sh -
        
        # Wait for K3s to be ready
        sleep 30
        
        # Create kubectl symlink
        sudo ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl
        
        # Set up kubeconfig for ubuntu user
        sudo mkdir -p /home/ubuntu/.kube
        sudo cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
        sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config
        sudo chmod 600 /home/ubuntu/.kube/config
        
        # Export KUBECONFIG for current session
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
        
        # Install NFS server for shared storage
        sudo apt update
        sudo apt install -y nfs-kernel-server
        sudo mkdir -p /mnt/data
        sudo chown nobody:nogroup /mnt/data
        sudo chmod 777 /mnt/data
        
        # Configure NFS exports
        echo "/mnt/data *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee /etc/exports
        sudo exportfs -a
        sudo systemctl restart nfs-kernel-server
    else
        export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    fi
    
    # Get Master IP and Token for workers
    CURRENT_MASTER_IP=$(hostname -I | awk '{print $1}')
    echo "$CURRENT_MASTER_IP" > ~/master_ip.txt
    
    if [ -f /var/lib/rancher/k3s/server/node-token ]; then
        sudo cat /var/lib/rancher/k3s/server/node-token > ~/master_token.txt
    fi
    
    # Try to set up workers via Salt if minions are available
    MINIONS=$(sudo salt-key -L 2>/dev/null | grep "mjcs2-k8s-worker" | wc -l)
    
    if [ "$MINIONS" -gt 0 ]; then
        # Update Salt state files with actual values
        if [ -f ~/master_ip.txt ] && [ -f ~/master_token.txt ]; then
            MASTER_IP_FILE=$(cat ~/master_ip.txt)
            TOKEN_FILE=$(cat ~/master_token.txt)
            sudo sed -i "s/<master_ip>/$MASTER_IP_FILE/g" /srv/salt/worker_setup.sls
            sudo sed -i "s/<k8s_token>/$TOKEN_FILE/g" /srv/salt/worker_setup.sls
            sudo salt 'mjcs2-k8s-worker*' state.apply worker_setup
        fi
    fi
    
    # Wait for cluster to stabilize
    sleep 60
    
    # Update k8s manifest with actual master IP for NFS
    sed -i "s/MASTER_IP_PLACEHOLDER/$CURRENT_MASTER_IP/g" k8s-app.yaml
    
    # Verify cluster is ready
    sudo kubectl get nodes || echo "Cluster not fully ready yet"
    
    # Deploy app
    sudo kubectl apply -f k8s-app.yaml
    
    # Wait for deployment
    sleep 30
    
    # Show final status
    echo ""
    echo "Final deployment status:"
    sudo kubectl get pods | grep stateful-app || echo "Pods not ready yet"
    sudo kubectl get services | grep stateful-app || echo "Service not ready yet"

    # Get service port for output
    SERVICE_PORT=$(sudo kubectl get service stateful-app-service -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "")
    
    if [ -n "$SERVICE_PORT" ]; then
        echo ""
        echo "Stateful App deployed!"
        echo "Application URL: http://$CURRENT_MASTER_IP:$SERVICE_PORT"
    fi
ENDSSH

# Create rollback commit
git add .
git commit -m "Rollback to version $ROLLBACK_VERSION - $(date)"

echo ""
echo "Successfully rolled back to version $ROLLBACK_VERSION"
echo "Current branch: $ROLLBACK_BRANCH"
echo "Version: $ROLLBACK_VERSION"
echo "Master IP: $MASTER_IP"

# Wait for pods to be ready and get service port
sleep 30

# Get the NodePort for stateful-app-service
SERVICE_PORT=$(ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo kubectl get service stateful-app-service -o jsonpath='{.spec.ports[0].nodePort}'" 2>/dev/null || echo "")

if [ -n "$SERVICE_PORT" ]; then
    echo "Application URL: http://$MASTER_IP:$SERVICE_PORT"
    echo ""
    echo "Stateful App deployed successfully!"
else
    echo "Could not determine service port. Check manually with:"
    echo "   ssh ubuntu@$MASTER_IP 'sudo kubectl get services'"
fi

echo ""
echo "Useful commands:"
echo "   SSH to master: ssh ubuntu@$MASTER_IP"
echo "   Check pods: ssh ubuntu@$MASTER_IP 'sudo kubectl get pods'"
echo "   Check services: ssh ubuntu@$MASTER_IP 'sudo kubectl get services'"
echo "   View logs: ssh ubuntu@$MASTER_IP 'sudo kubectl logs <pod-name>'"
echo "   View Git log: git log --oneline"
echo ""
echo "To return to this version: git checkout $ROLLBACK_VERSION"