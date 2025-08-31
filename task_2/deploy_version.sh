#!/bin/bash

# Load OpenStack environment
export OS_AUTH_URL="https://stack.dhbw.cloud:5000"
export OS_USERNAME="pfisterer-cloud-lecture"
export OS_PASSWORD="ss2025"
export OS_PROJECT_ID="6c1ae45e04f24dc695d6f526fce253c6"
export OS_USER_DOMAIN_NAME="default"

# Get version numbers
read -p "Enter infrastructure version number: " VERSION
read -p "Enter app version (for silasschroeder/stateful-app): " APP_VERSION

if [ -z "$VERSION" ]; then
    echo "Error: Infrastructure version number cannot be empty"
    exit 1
fi

if [ -z "$APP_VERSION" ]; then
    echo "Error: App version number cannot be empty"
    exit 1
fi

# Simple Git workflow
BRANCH_NAME="deploy-v$VERSION"

# Create and switch to new branch
if git show-ref --verify --quiet refs/heads/$BRANCH_NAME; then
    git checkout $BRANCH_NAME
else
    git checkout -b $BRANCH_NAME
fi

# Create Kubernetes manifest
cat > k8s-app.yaml << EOF
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
    server: MASTER_IP_PLACEHOLDER
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
spec:
  replicas: 3
  selector:
    matchLabels:
      app: stateful-app
  template:
    metadata:
      labels:
        app: stateful-app
    spec:
      containers:
        - name: stateful-container
          image: silasschroeder/stateful-app:v$APP_VERSION
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
      volumes:
        - name: app-data
          persistentVolumeClaim:
            claimName: app-data-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: stateful-app-service
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
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: stateful-app
  minReplicas: 1
  maxReplicas: 30
  targetCPUUtilizationPercentage: 30
EOF

# Git commit the changes
git add .
git commit -m "Deploy infrastructure v$VERSION with app v$APP_VERSION"

# Create Git tag
git tag -a "v$VERSION" -m "Infrastructure version $VERSION with app version $APP_VERSION"

# Push to GitHub (uncomment to enable)
# git push origin $BRANCH_NAME
# git push origin v$VERSION

echo "Git: Branch $BRANCH_NAME created and tagged as v$VERSION"

# Clean up any existing SSH known_hosts backup to prevent conflicts
if [ -f ~/.ssh/known_hosts.old ]; then
    rm -f ~/.ssh/known_hosts.old
    echo "Cleaned up existing SSH known_hosts backup"
fi

# Deploy infrastructure
tofu init
tofu apply -auto-approve

# Get master IP from OpenTofu output
echo "Infrastructure deployed! Extracting master IP..."

# First try to get IP from the new inventory file
if [ -f "openstack-inventory.txt" ]; then
    MASTER_IP=$(cat openstack-inventory.txt)
    echo "Master IP found: $MASTER_IP"
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

if [ -z "$MASTER_IP" ]; then
    echo "Could not extract master IP from any source. Please enter manually:"
    read -p "Enter master IP address: " MASTER_IP
fi

# Validate IP format (basic check)
if [[ ! "$MASTER_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "Warning: IP address format seems invalid: $MASTER_IP"
    read -p "Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "yes" ]; then
        echo "Deployment cancelled"
        exit 1
    fi
fi

if [ -z "$MASTER_IP" ]; then
    echo "Error: IP address cannot be empty"
    exit 1
fi

echo "Master IP: $MASTER_IP"
sleep 120

# Copy app manifest and deploy
scp -o StrictHostKeyChecking=no k8s-app.yaml ubuntu@$MASTER_IP:~/

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

echo ""
echo "========================================="
echo "Deployment completed!"
echo "========================================="
echo "Git: Changes committed and tagged as v$VERSION"
echo "Infrastructure version: $VERSION"
echo "App version: $APP_VERSION"
echo "Master IP: $MASTER_IP"
echo ""

# Wait for pods to be ready and get service port
sleep 30

# Get the NodePort
SERVICE_PORT=$(ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo kubectl get service stateful-app-service -o jsonpath='{.spec.ports[0].nodePort}'" 2>/dev/null || echo "")

if [ -n "$SERVICE_PORT" ]; then
    echo "Application URL: http://$MASTER_IP:$SERVICE_PORT"
    echo ""
    echo "Stateful App v$APP_VERSION deployed successfully!"
    echo "Infrastructure version: v$VERSION"
    echo "Access your app: http://$MASTER_IP:$SERVICE_PORT"
else
    echo "Could not determine service port. Check manually with:"
    echo "   ssh ubuntu@$MASTER_IP"
    echo "   sudo kubectl get services"
fi

echo ""
echo "Useful commands:"
echo "   SSH to master: ssh ubuntu@$MASTER_IP"
echo "   Check pods: ssh ubuntu@$MASTER_IP 'sudo kubectl get pods'"
echo "   Check services: ssh ubuntu@$MASTER_IP 'sudo kubectl get services'"
echo "   View logs: ssh ubuntu@$MASTER_IP 'sudo kubectl logs <pod-name>'"
echo ""
echo "To return to this version: git checkout v$VERSION"