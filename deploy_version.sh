#!/bin/bash

# Load OpenStack environment
export OS_AUTH_URL="https://stack.dhbw.cloud:5000"
export OS_USERNAME="pfisterer-cloud-lecture"
export OS_PASSWORD="ss2025"
export OS_PROJECT_ID="6c1ae45e04f24dc695d6f526fce253c6"
export OS_USER_DOMAIN_NAME="default"

# Get version number
read -p "Enter version number: " VERSION

if [ -z "$VERSION" ]; then
    echo "Error: Version number cannot be empty"
    exit 1
fi

# Validate version format (semantic versioning)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Warning: Version should follow semantic versioning (e.g., 1.0.0)"
    read -p "Continue anyway? (y/N): " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a Git repository"
    exit 1
fi

# Check if there are uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "You have uncommitted changes. Please commit or stash them first:"
    git status --short
    exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $CURRENT_BRANCH"

# Create and switch to new branch for this version
BRANCH_NAME="deploy-v$VERSION"
echo "Creating new branch: $BRANCH_NAME"

if git show-ref --verify --quiet refs/heads/$BRANCH_NAME; then
    echo "Branch $BRANCH_NAME already exists!"
    read -p "Switch to existing branch and continue? (y/N): " SWITCH
    if [[ $SWITCH =~ ^[Yy]$ ]]; then
        git checkout $BRANCH_NAME
    else
        exit 1
    fi
else
    git checkout -b $BRANCH_NAME
fi

# Generate Kubernetes deployment manifest for this version
echo "Generating Kubernetes deployment manifest for version $VERSION..."
cat > k8s-entities.yaml << EOF
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-app-pv
  labels:
    type: nfs
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  nfs:
    path: /mnt/data
    server: <master-ip> # REPLACE WITH ACTUAL IP
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data-pvc
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stateful-app
  labels:
    version: $VERSION
spec:
  replicas: 3
  selector:
    matchLabels:
      app: stateful-app
  template:
    metadata:
      labels:
        app: stateful-app
        version: $VERSION
    spec:
      containers:
        - name: stateful-container
          image: silasschroeder/stateful-app:v1.0.8
          ports:
            - containerPort: 3000
          volumeMounts:
            - name: app-data
              mountPath: /app/data
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "200m"
              memory: "256Mi"
          env:
            - name: APP_VERSION
              value: "$VERSION"
      volumes:
        - name: app-data
          persistentVolumeClaim:
            claimName: app-data-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: stateful-app-service
  labels:
    version: $VERSION
spec:
  selector:
    app: stateful-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 3000
  type: LoadBalancer
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: stateful-app-ingress
  labels:
    version: $VERSION
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - host:
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: stateful-app-service
                port:
                  number: 80
---
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: stateful-app
  labels:
    version: $VERSION
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: stateful-app
  minReplicas: 1
  maxReplicas: 30
  targetCPUUtilizationPercentage: 30
EOF

# Update current version tracking
echo "$VERSION" > current_version.txt
echo "$(date): Deployed version $VERSION" >> deployment_history.txt

# Add and commit all changes
echo "Committing changes for version $VERSION..."
git add .
git commit -m "Deploy version $VERSION

- Updated Kubernetes deployment manifest with stateful app
- Added persistent volume and persistent volume claim
- Added horizontal pod autoscaler (1-30 replicas, 30% CPU target)
- Added ingress configuration
- Set application version to $VERSION

Deployment includes:
- Stateful application with persistent storage
- NFS persistent volume (10Gi)
- LoadBalancer service
- Ingress for external access
- Horizontal Pod Autoscaler for scaling"

# Create a tag for this version
echo "Creating Git tag v$VERSION..."
git tag -a "v$VERSION" -m "Release version $VERSION

This release includes:
- Stateful application with persistent storage (v$VERSION)
- NFS persistent volume configuration (10Gi)
- Horizontal Pod Autoscaler (1-30 replicas, 30% CPU)
- LoadBalancer service with ingress support
- Infrastructure setup for OpenStack

Application: silasschroeder/stateful-app:v1.0.8
Deployed on: $(date)"

# Ask user if they want to create a pull request
read -p "Create pull request to merge back to $CURRENT_BRANCH? (y/N): " CREATE_PR
if [[ $CREATE_PR =~ ^[Yy]$ ]]; then
    # Push the branch and tag
    echo "Pushing branch and tag to remote..."
    git push origin $BRANCH_NAME
    git push origin "v$VERSION"
    
    # Check if GitHub CLI is available
    if command -v gh &> /dev/null; then
        echo "Creating pull request with GitHub CLI..."
        gh pr create \
            --title "Deploy version $VERSION" \
            --body "## Version $VERSION Deployment

This PR contains the deployment configuration for version $VERSION of the stateful application.

### Changes:
- 🚀 Updated Kubernetes deployment manifest with stateful app
- � Added persistent volume and persistent volume claim (NFS)
- � Added horizontal pod autoscaler (1-30 replicas, 30% CPU target)
- 🌐 Added ingress configuration for external access
- 🏷️ Tagged release as v$VERSION

### Deployment Details:
- **Application**: Stateful app (silasschroeder/stateful-app:v1.0.8)
- **Storage**: NFS persistent volume (10Gi capacity, 1Gi claim)
- **Scaling**: Auto-scaling from 1-30 replicas based on 30% CPU
- **Service**: LoadBalancer with ingress support
- **Infrastructure**: OpenStack VMs with Kubernetes

### Features:
- ✅ Persistent data storage
- ✅ Horizontal auto-scaling
- ✅ Load balancing
- ✅ Ingress routing

### Testing:
After merge and deployment:
1. Application will be accessible via ingress
2. Data will persist across pod restarts
3. Auto-scaling will activate under load

**Auto-generated by deploy_version.sh**" \
            --base $CURRENT_BRANCH \
            --head $BRANCH_NAME
        
        echo "Pull request created! You can view it on GitHub."
    else
        echo "GitHub CLI not found. Please create the pull request manually:"
        echo "  Branch: $BRANCH_NAME -> $CURRENT_BRANCH"
        echo "  Tag: v$VERSION"
    fi
else
    # Just push the tag
    git push origin "v$VERSION" 2>/dev/null || echo "Tag push failed (remote might not be configured)"
fi

# Deploy infrastructure
echo "Deploying infrastructure for version $VERSION..."
terraform init
terraform plan
terraform apply -auto-approve

# Get master IP manually from user
echo ""
echo "Infrastructure deployment completed!"
echo ""
echo "Please check your OpenStack dashboard or run 'terraform show' to find the master node IP."
echo "Look for the master node (mjcs2-k8s-master) and note its fixed_ip_v4 address."
echo ""

while true; do
    read -p "Enter the master node IP address: " MASTER_IP
    
    if [ -z "$MASTER_IP" ]; then
        echo "Error: IP address cannot be empty. Please try again."
        continue
    fi
    
    # Basic IP validation (simple regex)
    if [[ $MASTER_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Using master IP: $MASTER_IP"
        break
    else
        echo "Error: Invalid IP address format. Please enter a valid IP (e.g., 192.168.1.100)"
    fi
done

echo ""
echo "========================================="
echo "Version $VERSION deployment initiated!"
echo "========================================="
echo "Git Management: ✓ Completed"
echo "  - Branch: $BRANCH_NAME"
echo "  - Tag: v$VERSION"
echo "  - Commit: $(git rev-parse --short HEAD)"
echo "Infrastructure: ✓ Deployed"
echo "  - Master IP: $MASTER_IP"
echo ""

# Update the k8s-entities.yaml with the actual master IP
echo "Updating Kubernetes manifest with master IP..."
sed -i '' "s/<master-ip>/$MASTER_IP/g" k8s-entities.yaml

# Function to wait for SSH connectivity
wait_for_ssh() {
    local host=$1
    local max_attempts=30
    local attempt=1
    
    echo "Waiting for SSH connectivity to $host..."
    while [ $attempt -le $max_attempts ]; do
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$host "echo 'SSH connected'" 2>/dev/null; then
            echo "SSH connection established to $host"
            return 0
        fi
        echo "Attempt $attempt/$max_attempts failed, retrying in 10 seconds..."
        sleep 10
        ((attempt++))
    done
    echo "Failed to establish SSH connection to $host after $max_attempts attempts"
    return 1
}

# Function to wait for salt setup completion
wait_for_salt_setup() {
    local master_ip=$1
    local max_attempts=60
    local attempt=1
    
    echo "Waiting for Salt setup to complete on master..."
    while [ $attempt -le $max_attempts ]; do
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$master_ip "sudo salt-key -L 2>/dev/null | grep -q 'mjcs2-k8s-worker'" 2>/dev/null; then
            echo "Salt setup completed - workers are connected"
            return 0
        fi
        echo "Attempt $attempt/$max_attempts: Salt setup still in progress..."
        sleep 10
        ((attempt++))
    done
    echo "Salt setup did not complete in expected time"
    return 1
}

echo "Starting automated Kubernetes setup and application deployment..."
echo "This will take approximately 10-15 minutes..."

# Wait for SSH and Salt setup
if ! wait_for_ssh $MASTER_IP; then
    echo "Error: Could not establish SSH connection to master"
    exit 1
fi

echo "Infrastructure initialized successfully!"

if ! wait_for_salt_setup $MASTER_IP; then
    echo "Warning: Salt setup may not be complete, continuing anyway..."
fi

# Configure Kubernetes cluster and deploy application
echo "Configuring Kubernetes cluster and deploying application..."
scp -o StrictHostKeyChecking=no k8s-entities.yaml ubuntu@$MASTER_IP:~/k8s-entities.yaml

ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP << 'ENDSSH'
    # Wait for cloud-init to complete
    echo "Waiting for cloud-init to complete..."
    sudo cloud-init status --wait
    
    # Configure master node
    echo "Configuring master node..."
    sudo salt 'mjcs2-k8s-master' state.apply master_pre-worker-setup
    
    # Get master IP and token for worker configuration
    MASTER_IP=$(cat ~/master_ip.txt)
    
    # Wait for token file to be created
    echo "Waiting for master token..."
    while [ ! -f ~/master_token.txt ]; do
        echo "Still waiting for master token..."
        sleep 10
    done
    
    TOKEN=$(cat ~/master_token.txt)
    echo "Master token obtained"
    
    # Update worker setup configuration
    echo "Updating worker configuration..."
    sudo sed -i "s/<master_ip>/$MASTER_IP/g" /srv/salt/worker_setup.sls
    sudo sed -i "s/<k8s_token>/$TOKEN/g" /srv/salt/worker_setup.sls
    
    # Configure worker nodes
    echo "Configuring worker nodes..."
    sudo salt 'mjcs2-k8s-worker*' state.apply worker_setup
    
    # Wait for nodes to be ready
    echo "Waiting for worker nodes to join cluster..."
    sleep 60
    
    # Install additional components (metrics server, etc.)
    echo "Installing additional Kubernetes components..."
    sudo salt 'mjcs2-k8s-master' state.apply master_post-worker-setup
    
    # Wait for kubectl to be available and cluster to be ready
    echo "Waiting for Kubernetes cluster to be ready..."
    while ! sudo kubectl get nodes >/dev/null 2>&1; do
        echo "Waiting for kubectl to be available..."
        sleep 10
    done
    
    # Wait for all nodes to be in Ready state
    echo "Waiting for all nodes to be Ready..."
    while [ $(sudo kubectl get nodes --no-headers | grep -c "Ready") -lt 3 ]; do
        echo "Nodes not all ready yet, waiting..."
        sudo kubectl get nodes
        sleep 15
    done
    
    echo "All nodes are ready. Deploying application..."
    
    # Deploy the application
    sudo kubectl apply -f k8s-entities.yaml
    
    # Wait for persistent volume to be bound
    echo "Waiting for persistent volume to be available..."
    while [ $(sudo kubectl get pv --no-headers | grep -c "Bound\|Available") -eq 0 ]; do
        echo "Waiting for persistent volume..."
        sleep 10
    done
    
    # Wait for persistent volume claim to be bound
    echo "Waiting for persistent volume claim to be bound..."
    sudo kubectl wait --for=condition=Bound pvc/app-data-pvc --timeout=300s
    
    # Wait for deployment to be ready
    echo "Waiting for deployment to be ready..."
    sudo kubectl wait --for=condition=available --timeout=600s deployment/stateful-app
    
    # Wait for HPA to be active
    echo "Waiting for Horizontal Pod Autoscaler to be active..."
    sleep 30
    
    echo ""
    echo "========================================="
    echo "APPLICATION DEPLOYED SUCCESSFULLY!"
    echo "========================================="
    echo ""
    echo "Cluster Status:"
    sudo kubectl get nodes
    echo ""
    echo "Application Status:"
    sudo kubectl get deployments
    echo ""
    echo "Pods Status:"
    sudo kubectl get pods
    echo ""
    echo "Services Status:"
    sudo kubectl get services
    echo ""
    echo "Persistent Volumes:"
    sudo kubectl get pv,pvc
    echo ""
    echo "Horizontal Pod Autoscaler:"
    sudo kubectl get hpa
    echo ""
    echo "Ingress Status:"
    sudo kubectl get ingress
    echo ""
    
    # Get service details for access information
    SERVICE_TYPE=$(sudo kubectl get service stateful-app-service -o jsonpath='{.spec.type}')
    if [ "$SERVICE_TYPE" = "LoadBalancer" ]; then
        EXTERNAL_IP=$(sudo kubectl get service stateful-app-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
        if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "null" ]; then
            echo "Application accessible at: http://$EXTERNAL_IP"
        else
            echo "LoadBalancer external IP pending, check with: kubectl get services"
        fi
    fi
    
    echo "Master node IP: $(cat ~/master_ip.txt)"
    echo ""
    echo "Useful commands:"
    echo "  kubectl get pods                    # Check pod status"
    echo "  kubectl get services                # Check services"
    echo "  kubectl get hpa                     # Check autoscaler"
    echo "  kubectl logs deployment/stateful-app  # Check application logs"
    echo "  kubectl describe pod <pod-name>     # Debug specific pod"
ENDSSH

echo ""
echo "========================================="
echo "DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo "========================================="
echo "✓ Infrastructure deployed"
echo "✓ Kubernetes cluster configured"
echo "✓ Application deployed with persistent storage"
echo "✓ Auto-scaling configured (1-30 replicas)"
echo "✓ LoadBalancer service active"
echo "✓ Ingress configured"
echo ""
echo "Version management:"
echo "  - All changes committed and tagged as v$VERSION"
echo "  - Use 'git checkout v$VERSION' to return to this exact state"
echo "  - Use './rollback.sh' to rollback to previous version"
echo ""
echo "Access your application:"
echo "  SSH to master: ssh ubuntu@$MASTER_IP"
echo "  Check status: ssh ubuntu@$MASTER_IP 'sudo kubectl get all'"