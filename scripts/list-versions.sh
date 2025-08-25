#!/bin/bash

# Version Management Overview Script
# Usage: ./list-versions.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Infrastructure and Application Version Overview ==="
echo ""

cd "$PROJECT_DIR"

# Show current terraform state
echo "Current Terraform State:"
if terraform show > /dev/null 2>&1; then
    echo "  Infrastructure is currently deployed"
    if terraform output master_ip > /dev/null 2>&1; then
        CURRENT_MASTER_IP=$(terraform output -raw master_ip 2>/dev/null || echo "N/A")
        CURRENT_INFRA_VERSION=$(terraform output -raw infrastructure_version 2>/dev/null || echo "N/A")
        CURRENT_APP_VERSION=$(terraform output -raw app_version 2>/dev/null || echo "N/A")
        echo "  Current Master IP: $CURRENT_MASTER_IP"
        echo "  Current Infrastructure Version: $CURRENT_INFRA_VERSION"
        echo "  Current Application Version: $CURRENT_APP_VERSION"
    fi
else
    echo "  No infrastructure currently deployed"
fi

echo ""
echo "Available Deployment Versions:"
if ls deployment-*.info > /dev/null 2>&1; then
    for info_file in deployment-*.info; do
        version=$(echo "$info_file" | sed 's/deployment-\(.*\)\.info/\1/')
        echo "  Version: $version"
        
        # Show key info from deployment file
        if [ -f "$info_file" ]; then
            app_ver=$(grep "Application Version:" "$info_file" | cut -d' ' -f3 2>/dev/null || echo "N/A")
            deploy_time=$(grep "Deployment Time:" "$info_file" | cut -d' ' -f3- 2>/dev/null || grep "Last Update:" "$info_file" | cut -d' ' -f3- 2>/dev/null || echo "N/A")
            master_ip=$(grep "Master IP:" "$info_file" | cut -d' ' -f3 2>/dev/null || echo "N/A")
            
            echo "    App Version: $app_ver"
            echo "    Last Deploy: $deploy_time"
            echo "    Master IP: $master_ip"
            
            # Check if there's rollback info
            if grep -q "Rollback Performed:" "$info_file"; then
                rollback_time=$(grep "Rollback Performed:" "$info_file" | cut -d' ' -f3- || echo "N/A")
                echo "    Rollback: $rollback_time"
            fi
        fi
        echo ""
    done
else
    echo "  No deployment versions found"
fi

echo "Available Kubernetes Manifests:"
if ls k8s-entities-*.yaml > /dev/null 2>&1; then
    for manifest in k8s-entities-*.yaml; do
        version=$(echo "$manifest" | sed 's/k8s-entities-\(.*\)\.yaml/\1/')
        echo "  $manifest (version: $version)"
    done
else
    echo "  No Kubernetes manifests found"
fi

echo ""
echo "Git Repository Status:"
echo "  Current branch: $(git branch --show-current 2>/dev/null || echo 'N/A')"
echo "  Last commit: $(git log -1 --oneline 2>/dev/null || echo 'N/A')"

echo ""
echo "Usage Commands:"
echo "  Deploy new version:    ./scripts/deploy-version.sh [infra_version] [app_version] apply"
echo "  Update app version:    ./scripts/update-app-version.sh [app_version] [master_ip]"
echo "  Rollback to version:   ./scripts/rollback.sh [target_version]"
echo "  Plan deployment:       ./scripts/deploy-version.sh [infra_version] [app_version] plan"
echo "  Destroy deployment:    ./scripts/deploy-version.sh [infra_version] [app_version] destroy"