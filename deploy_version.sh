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
spec:
  replicas: 3
  selector:
    matchLabels:
      app: simple-counter-app
  template:
    metadata:
      labels:
        app: simple-counter-app
    spec:
      containers:
      - name: simple-counter-app
        image: node:18-alpine
        ports:
        - containerPort: 3000
        env:
        - name: DATA_DIR
          value: "/shared-data"
        volumeMounts:
        - name: shared-counter-storage
          mountPath: /shared-data
        command: ["sh", "-c"]
        args:
        - |
          cd /tmp && npm init -y && npm install express --save
          cat > app.js << 'APPEOF'
          const express = require('express');
          const fs = require('fs');
          const path = require('path');
          const app = express();
          
          const dataDir = process.env.DATA_DIR || '/shared-data';
          const counterFile = path.join(dataDir, 'global-counter.txt');
          
          if (!fs.existsSync(dataDir)) {
            fs.mkdirSync(dataDir, { recursive: true });
          }
          
          function readCounter() {
            try {
              if (fs.existsSync(counterFile)) {
                return parseInt(fs.readFileSync(counterFile, 'utf8')) || 0;
              }
              return 0;
            } catch (err) {
              return 0;
            }
          }
          
          function writeCounter(count) {
            try {
              fs.writeFileSync(counterFile, count.toString());
            } catch (err) {
              console.error('Error writing counter:', err);
            }
          }
          
          app.get('/', (req, res) => {
            const counter = readCounter() + 1;
            writeCounter(counter);
            
            const pod = process.env.HOSTNAME || 'unknown-pod';
            const html = \`<!DOCTYPE html>
            <html>
            <head><title>Global Counter v${VERSION}</title></head>
            <body style="font-family: Arial; text-align: center; margin: 50px;">
                <h1 style="color: green;">🌍 Global Counter v${VERSION}</h1>
                <h2 style="color: blue; font-size: 5em;">\${counter}</h2>
                <p><strong>🔢 Globale Aufrufe über ALLE Worker</strong></p>
                <p><strong>🚀 Pod:</strong> \${pod}</p>
                <p><em>⏰ Zeit:</em> \${new Date().toLocaleString('de-DE')}</p>
                <button onclick="location.reload()" style="padding: 15px 30px; font-size: 18px; margin: 10px; background: blue; color: white; border: none; cursor: pointer;">
                    🔄 Counter erhöhen
                </button>
                <a href="/reset" style="display: inline-block; padding: 15px 30px; font-size: 18px; margin: 10px; background: red; color: white; text-decoration: none;">
                    🗑️ Reset
                </a>
            </body>
            </html>\`;
            res.send(html);
          });
          
          app.get('/reset', (req, res) => {
            writeCounter(0);
            res.redirect('/');
          });
          
          app.listen(3000, '0.0.0.0', () => {
            console.log('🚀 Global Counter App started on port 3000');
            console.log('📊 Current counter:', readCounter());
          });
          APPEOF
          node app.js
      volumes:
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

# Get master IP from user
echo ""
echo "Infrastructure deployed! Please find the master node IP."
read -p "Enter master IP address: " MASTER_IP

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
    sudo cloud-init status --wait
    
    # Configure Kubernetes
    echo "Setting up Kubernetes..."
    sudo salt 'mjcs2-k8s-master' state.apply master_pre-worker-setup
    
    # Configure workers
    MASTER_IP=$(cat ~/master_ip.txt)
    TOKEN=$(cat ~/master_token.txt)
    sudo sed -i "s/<master_ip>/$MASTER_IP/g" /srv/salt/worker_setup.sls
    sudo sed -i "s/<k8s_token>/$TOKEN/g" /srv/salt/worker_setup.sls
    sudo salt 'mjcs2-k8s-worker*' state.apply worker_setup
    
    # Wait for cluster
    echo "Waiting for cluster to be ready..."
    sleep 60
    
    # Update k8s manifest with actual master IP for NFS
    echo "Configuring shared storage with Master IP..."
    sed -i "s/MASTER_IP_PLACEHOLDER/$MASTER_IP/g" k8s-app.yaml
    
    # Deploy app
    echo "Deploying global counter application..."
    sudo kubectl apply -f k8s-app.yaml
    
    echo "Deployment complete!"
    sudo kubectl get pods
    sudo kubectl get services
    
    echo ""
    echo "🌍 Global Counter App deployed with shared NFS storage!"
    echo "📊 All worker pods share the same counter state"
ENDSSH

echo ""
echo "========================================="
echo "Deployment completed!"
echo "========================================="
echo "Git: Changes committed and tagged as v$VERSION"
echo "Access: ssh ubuntu@$MASTER_IP"
echo "Check: kubectl get pods"
echo ""
echo "To return to this version: git checkout v$VERSION"