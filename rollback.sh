#!/bin/bash

# Load OpenStack environment
export OS_AUTH_URL="https://stack.dhbw.cloud:5000"
export OS_USERNAME="pfisterer-cloud-lecture"
export OS_PASSWORD="ss2025"
export OS_PROJECT_ID="6c1ae45e04f24dc695d6f526fce253c6"
export OS_USER_DOMAIN_NAME="default"

# Show available versions
echo "Available versions:"
ls -1 versions/ | grep -v "current_version.txt" | grep -v "deployment_history.txt"
echo ""

# Get version to rollback to
read -p "Enter version to rollback to (or 'previous' for last version): " ROLLBACK_VERSION

if [ "$ROLLBACK_VERSION" = "previous" ]; then
    # Get previous version from history (second to last line)
    ROLLBACK_VERSION=$(tail -2 versions/deployment_history.txt | head -1 | awk '{print $NF}')
fi

if [ -z "$ROLLBACK_VERSION" ] || [ ! -d "versions/$ROLLBACK_VERSION" ]; then
    echo "Error: Version $ROLLBACK_VERSION not found"
    exit 1
fi

# Destroy current infrastructure
echo "Destroying current infrastructure..."
terraform destroy -auto-approve

# Restore version files
echo "Restoring version $ROLLBACK_VERSION..."
cp "versions/$ROLLBACK_VERSION/initialisation.tf" ./
cp "versions/$ROLLBACK_VERSION/terraform.tfvars" ./
rm -rf sample-app
cp -r "versions/$ROLLBACK_VERSION/sample-app" ./

# Deploy restored version
echo "Deploying version $ROLLBACK_VERSION..."
terraform init
terraform plan
terraform apply -auto-approve

# Update current version
echo "$ROLLBACK_VERSION" > versions/current_version.txt
echo "$(date): Rolled back to version $ROLLBACK_VERSION" >> versions/deployment_history.txt

echo "Successfully rolled back to version $ROLLBACK_VERSION"