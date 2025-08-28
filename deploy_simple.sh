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
        command: ["sh", "-c"]
        args:
        - |
          npm install express
          node -e "
          const express = require('express');
          const app = express();
          let counter = 0;
          
          app.get('/', (req, res) => {
            counter++;
            const pod = process.env.HOSTNAME || 'unknown-pod';
            const html = \`
            <html>
            <head><title>Simple Counter App</title></head>
            <body style='font-family: Arial; text-align: center; margin: 50px;'>
              <h1>Simple Counter App v${VERSION}</h1>
              <h2 style='color: blue; font-size: 3em;'>\${counter}</h2>
              <p>Aufrufe insgesamt</p>
              <p><strong>Pod:</strong> \${pod}</p>
              <p><em>Aktualisiert: \${new Date().toLocaleString('de-DE')}</em></p>
              <button onclick='location.reload()'>Aktualisieren</button>
            </body>
            </html>
            \`;
            res.send(html);
          });
          
          app.listen(3000, '0.0.0.0', () => {
            console.log('App running on port 3000');
          });
          "
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
    
    # Deploy app
    echo "Deploying application..."
    sudo kubectl apply -f k8s-app.yaml
    
    echo "Deployment complete!"
    sudo kubectl get pods
    sudo kubectl get services
ENDSSH

echo ""
echo "========================================="
echo "Deployment completed!"
echo "========================================="
echo "Access: ssh ubuntu@$MASTER_IP"
echo "Check: kubectl get pods"