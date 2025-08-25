#!/bin/bash

# Demonstration of Infrastructure and Application Versioning
# This script shows how the versioning system works without requiring actual deployment

set -e

echo "=== Infrastructure and Application Versioning Demonstration ==="
echo ""

# Create demo directory
mkdir -p demo-output
cd demo-output

echo "1. Creating sample deployment scenarios..."

# Simulate deployment info files for different versions
cat > deployment-v1.0.0.info <<EOF
Infrastructure Version: v1.0.0
Application Version: 1.0.0
Master IP: 192.168.1.100
Deployment Time: $(date)
K8s Manifest: k8s-entities-v1.0.0.yaml
EOF

cat > deployment-v1.1.0.info <<EOF
Infrastructure Version: v1.1.0
Application Version: 1.1.0
Master IP: 192.168.1.110
Deployment Time: $(date)
K8s Manifest: k8s-entities-v1.1.0.yaml
EOF

cat > deployment-v1.2.0.info <<EOF
Infrastructure Version: v1.2.0
Application Version: 1.2.0
Master IP: 192.168.1.120
Deployment Time: $(date)
K8s Manifest: k8s-entities-v1.2.0.yaml
EOF

echo "✓ Created deployment info files for versions v1.0.0, v1.1.0, v1.2.0"

echo ""
echo "2. Generating sample Kubernetes manifests with different versions..."

# Generate sample k8s manifests for each version
for version in "v1.0.0" "v1.1.0" "v1.2.0"; do
    app_version=$(echo $version | sed 's/v//')
    
    cat > "k8s-entities-${version}.yaml" <<EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-web-app
  labels:
    app: sample-web-app
    version: ${app_version}
spec:
  replicas: 3
  selector:
    matchLabels:
      app: sample-web-app
  template:
    metadata:
      labels:
        app: sample-web-app
        version: ${app_version}
    spec:
      containers:
        - name: sample-web-app
          image: node:16-alpine
          env:
            - name: APP_VERSION
              value: "${app_version}"
          command:
            - /bin/sh
            - -c
            - |
              echo "Sample Web Application - Version ${app_version}"
              echo "This demonstrates version ${app_version} deployment"
              while true; do sleep 30; done
---
apiVersion: v1
kind: Service
metadata:
  name: sample-web-app-service
spec:
  selector:
    app: sample-web-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 3000
  type: LoadBalancer
EOF
    echo "✓ Generated k8s-entities-${version}.yaml"
done

echo ""
echo "3. Demonstrating Terraform variables for different versions..."

# Show terraform.tfvars examples for different versions
cat > terraform-v1.0.0.tfvars <<EOF
infrastructure_version = "v1.0.0"
app_version = "1.0.0"
worker_count = 2
app_replicas = 3
min_replicas = 1
max_replicas = 10
EOF

cat > terraform-v1.1.0.tfvars <<EOF
infrastructure_version = "v1.1.0"
app_version = "1.1.0"
worker_count = 3
app_replicas = 5
min_replicas = 2
max_replicas = 15
EOF

cat > terraform-v1.2.0.tfvars <<EOF
infrastructure_version = "v1.2.0"
app_version = "1.2.0"
worker_count = 2
app_replicas = 4
min_replicas = 1
max_replicas = 20
EOF

echo "✓ Generated Terraform variable files for different versions"

echo ""
echo "4. Showing version management capabilities..."

echo ""
echo "📋 Available Deployment Versions:"
for info_file in deployment-*.info; do
    if [ -f "$info_file" ]; then
        version=$(echo "$info_file" | sed 's/deployment-\(.*\)\.info/\1/')
        echo "  📦 Version: $version"
        
        app_ver=$(grep "Application Version:" "$info_file" | cut -d' ' -f3)
        deploy_time=$(grep "Deployment Time:" "$info_file" | cut -d' ' -f3-)
        master_ip=$(grep "Master IP:" "$info_file" | cut -d' ' -f3)
        
        echo "    🔗 App Version: $app_ver"
        echo "    📅 Deploy Time: $deploy_time"
        echo "    🌐 Master IP: $master_ip"
        echo ""
    fi
done

echo "📋 Available Kubernetes Manifests:"
for manifest in k8s-entities-*.yaml; do
    if [ -f "$manifest" ]; then
        version=$(echo "$manifest" | sed 's/k8s-entities-\(.*\)\.yaml/\1/')
        echo "  📄 $manifest (version: $version)"
    fi
done

echo ""
echo "📋 Available Terraform Configurations:"
for tfvars in terraform-*.tfvars; do
    if [ -f "$tfvars" ]; then
        version=$(echo "$tfvars" | sed 's/terraform-\(.*\)\.tfvars/\1/')
        echo "  ⚙️  $tfvars (version: $version)"
        echo "     $(grep 'infrastructure_version' "$tfvars")"
        echo "     $(grep 'app_version' "$tfvars")"
        echo "     $(grep 'worker_count' "$tfvars")"
    fi
done

echo ""
echo "5. Simulating version management commands..."

echo ""
echo "🚀 Deployment Commands (examples):"
echo "  Deploy v1.0.0:        ./scripts/deploy-version.sh v1.0.0 1.0.0 apply"
echo "  Deploy v1.1.0:        ./scripts/deploy-version.sh v1.1.0 1.1.0 apply"
echo "  Deploy v1.2.0:        ./scripts/deploy-version.sh v1.2.0 1.2.0 apply"

echo ""
echo "🔄 Application Update Commands (examples):"
echo "  Update to app v1.1.0:  ./scripts/update-app-version.sh 1.1.0 192.168.1.100"
echo "  Update to app v1.2.0:  ./scripts/update-app-version.sh 1.2.0 192.168.1.100"

echo ""
echo "⏪ Rollback Commands (examples):"
echo "  Rollback to v1.0.0:    ./scripts/rollback.sh v1.0.0"
echo "  Rollback to v1.1.0:    ./scripts/rollback.sh v1.1.0"

echo ""
echo "📊 Version Overview:"
echo "  List all versions:     ./scripts/list-versions.sh"

echo ""
echo "6. Demonstrating Infrastructure Changes Between Versions..."

echo ""
echo "🔍 Differences between versions:"
echo ""
echo "v1.0.0 → v1.1.0 changes:"
echo "  • Worker count: 2 → 3"
echo "  • App replicas: 3 → 5"
echo "  • Max replicas: 10 → 15"
echo "  • Application version: 1.0.0 → 1.1.0"
echo ""
echo "v1.1.0 → v1.2.0 changes:"
echo "  • Worker count: 3 → 2"
echo "  • App replicas: 5 → 4"
echo "  • Max replicas: 15 → 20"
echo "  • Application version: 1.1.0 → 1.2.0"

echo ""
echo "7. Version Rollback Simulation..."

echo ""
echo "📝 Rollback Process Example:"
echo "  1. Current version: v1.2.0"
echo "  2. Target version: v1.0.0"
echo "  3. Process:"
echo "     a) Destroy current infrastructure (v1.2.0)"
echo "     b) Deploy target infrastructure (v1.0.0)"
echo "     c) Apply v1.0.0 Kubernetes manifests"
echo "     d) Update deployment info with rollback timestamp"

# Simulate rollback info update
cat >> deployment-v1.0.0.info <<EOF
Rollback Performed: $(date)
New Master IP: 192.168.1.100
EOF

echo "  ✓ Rollback simulation completed"

echo ""
echo "=== Demonstration Complete ==="
echo ""
echo "📁 Generated files in demo-output/:"
ls -la
echo ""
echo "🎯 Key Features Demonstrated:"
echo "  ✅ Infrastructure versioning with Terraform variables"
echo "  ✅ Application versioning through environment variables"
echo "  ✅ Version-specific Kubernetes manifests"
echo "  ✅ Deployment tracking and history"
echo "  ✅ Rollback capability to any previous version"
echo "  ✅ Automated scripts for version management"
echo ""
echo "📚 For actual deployment, use the scripts in the scripts/ directory"
echo "   with a properly configured Terraform/OpenStack environment."

cd ..
echo ""
echo "Demo output saved in: $(pwd)/demo-output/"