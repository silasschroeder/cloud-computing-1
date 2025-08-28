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

# Simple Git workflow
BRANCH_NAME="deploy-v$VERSION"
echo "Creating Git branch: $BRANCH_NAME"

# Create and switch to new branch
if git show-ref --verify --quiet refs/heads/$BRANCH_NAME; then
    echo "Branch $BRANCH_NAME already exists, switching to it..."
    git checkout $BRANCH_NAME
else
    git checkout -b $BRANCH_NAME
fi

# Create simple Kubernetes manifest
echo "Creating Kubernetes manifest for version $VERSION..."
cat > k8s-app.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: simple-counter-app
  labels:
    app: simple-counter-app
    version: $VERSION
spec:
  replicas: 3
  selector:
    matchLabels:
      app: simple-counter-app
  template:
    metadata:
      labels:
        app: simple-counter-app
        version: $VERSION
    spec:
      containers:
      - name: simple-counter-app
        image: node:18-alpine
        ports:
        - containerPort: 3000
        env:
        - name: DATA_DIR
          value: "/shared-data"
        - name: APP_VERSION
          value: "$VERSION"
        - name: PORT
          value: "3000"
        volumeMounts:
        - name: shared-counter-storage
          mountPath: /shared-data
        - name: app-code
          mountPath: /app-source
        workingDir: /app
        command: ["sh", "-c"]
        args:
        - |
          # Copy application files to working directory
          cp -r /app-source/* /app/
          
          # Install dependencies
          npm install
          
          # Start application
          npm start
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: shared-counter-storage
        nfs:
          server: MASTER_IP_PLACEHOLDER
          path: /mnt/data
      - name: app-code
        configMap:
          name: app-source-$VERSION
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-source-$VERSION
data:
  package.json: |
$(cat app/package.json | sed 's/^/    /')
  server.js: |
$(cat app/server.js | sed 's/^/    /')
---
      - name: shared-counter-storage
        nfs:
          server: MASTER_IP_PLACEHOLDER
          path: /mnt/data
---
apiVersion: v1
kind: Service
metadata:
  name: simple-counter-service
spec:
  selector:
    app: simple-counter-app
  ports:
  - port: 80
    targetPort: 3000
  type: NodePort
EOF

# Git commit the changes
echo "Committing changes to Git..."
git add .
git commit -m "Deploy version $VERSION - Simple counter app with $VERSION"

# Create Git tag
echo "Creating Git tag v$VERSION..."
git tag -a "v$VERSION" -m "Release version $VERSION"

echo "Git: Branch $BRANCH_NAME created and tagged as v$VERSION"

# Deploy infrastructure
echo "Deploying infrastructure..."
terraform init
terraform apply -auto-approve

# Get master IP from Terraform output
echo ""
echo "Infrastructure deployed! Extracting master IP from Terraform state..."
MASTER_IP=$(grep -A 3 "mjcs2-k8s-master" terraform.tfstate | grep "access_ip_v4" | cut -d'"' -f4)

if [ -z "$MASTER_IP" ]; then
    echo "Could not extract master IP from Terraform. Please enter manually:"
    read -p "Enter master IP address: " MASTER_IP
fi

if [ -z "$MASTER_IP" ]; then
    echo "Error: IP address cannot be empty"
    exit 1
fi

echo "Master IP: $MASTER_IP"
echo "Waiting for infrastructure to be ready..."
sleep 120

# Copy app manifest and deploy
echo "Deploying application..."
scp -o StrictHostKeyChecking=no k8s-app.yaml ubuntu@$MASTER_IP:~/

ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP << 'ENDSSH'
    # Wait for cloud-init
    echo "⏳ Waiting for cloud-init to complete..."
    sudo cloud-init status --wait
    
    # Configure Kubernetes
    echo "🚀 Setting up Kubernetes master..."
    sudo salt 'mjcs2-k8s-master' state.apply master_pre-worker-setup
    
    # Configure workers
    echo "🔧 Configuring worker nodes..."
    MASTER_IP=$(cat ~/master_ip.txt)
    TOKEN=$(cat ~/master_token.txt)
    sudo sed -i "s/<master_ip>/$MASTER_IP/g" /srv/salt/worker_setup.sls
    sudo sed -i "s/<k8s_token>/$TOKEN/g" /srv/salt/worker_setup.sls
    sudo salt 'mjcs2-k8s-worker*' state.apply worker_setup
    
    # Wait for cluster
    echo "⏳ Waiting for cluster to be ready..."
    sleep 60
    
    # Update k8s manifest with actual master IP for NFS
    echo "📁 Configuring shared storage with Master IP..."
    sed -i "s/MASTER_IP_PLACEHOLDER/$MASTER_IP/g" k8s-app.yaml
    
    # Verify cluster is ready
    echo "🔍 Verifying cluster status..."
    sudo kubectl get nodes
    
    # Deploy app
    echo "🚀 Deploying global counter application..."
    sudo kubectl apply -f k8s-app.yaml
    
    # Wait for deployment
    echo "⏳ Waiting for pods to start..."
    sleep 30
    
    # Show final status
    echo ""
    echo "📊 Final deployment status:"
    sudo kubectl get pods | grep simple-counter
    sudo kubectl get services | grep simple-counter
    
    # Get service port for output
    SERVICE_PORT=$(sudo kubectl get service simple-counter-service -o jsonpath='{.spec.ports[0].nodePort}')
    echo ""
    echo "🌍 Global Counter App deployed with shared NFS storage!"
    echo "📊 All worker pods share the same counter state"
    echo "🔗 Application URL: http://$MASTER_IP:$SERVICE_PORT"
ENDSSH

echo ""
echo "========================================="
echo "Deployment completed!"
echo "========================================="
echo "Git: Changes committed and tagged as v$VERSION"
echo "Master IP: $MASTER_IP"
echo ""

# Wait for pods to be ready and get service port
echo "🔍 Waiting for application to be ready..."
sleep 30

# Get the NodePort
SERVICE_PORT=$(ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo kubectl get service simple-counter-service -o jsonpath='{.spec.ports[0].nodePort}'" 2>/dev/null || echo "")

if [ -n "$SERVICE_PORT" ]; then
    echo "🌐 Application URL: http://$MASTER_IP:$SERVICE_PORT"
    echo ""
    
    # Test the application
    echo "🧪 Testing application..."
    for i in {1..3}; do
        COUNTER=$(curl -s http://$MASTER_IP:$SERVICE_PORT 2>/dev/null | grep -o '<h2[^>]*>[^<]*</h2>' | sed 's/<[^>]*>//g' 2>/dev/null || echo "N/A")
        if [ "$COUNTER" != "N/A" ]; then
            echo "✅ Test $i: Counter = $COUNTER"
        else
            echo "⏳ Test $i: Application still starting..."
        fi
        sleep 2
    done
    echo ""
    echo "🎉 Global Counter App v$VERSION deployed successfully!"
    echo "🔗 Access your app: http://$MASTER_IP:$SERVICE_PORT"
else
    echo "⚠️  Could not determine service port. Check manually with:"
    echo "   ssh ubuntu@$MASTER_IP"
    echo "   sudo kubectl get services"
fi

echo ""
echo "📋 Useful commands:"
echo "   SSH to master: ssh ubuntu@$MASTER_IP"
echo "   Check pods: ssh ubuntu@$MASTER_IP 'sudo kubectl get pods'"
echo "   Check services: ssh ubuntu@$MASTER_IP 'sudo kubectl get services'"
echo "   View logs: ssh ubuntu@$MASTER_IP 'sudo kubectl logs <pod-name>'"
echo ""
echo "🔄 To return to this version: git checkout v$VERSION"