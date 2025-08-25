# Cloud-Computing-und-Big-Data

## Enhanced Infrastructure with Application Versioning

This repository demonstrates the implementation of infrastructure and application versioning with rollback capabilities using Terraform, Kubernetes, and automated deployment scripts.

## Features

- **Infrastructure Versioning**: Version-tagged infrastructure deployments
- **Application Versioning**: Configurable application versions through environment variables
- **Rollback Capability**: Easy rollback to previous infrastructure and application versions
- **Automated Deployment**: Scripts for automated version management
- **Version Tracking**: Deployment history and version information

## Quick Start

### 1. Configure Environment

Create and configure `env.sh`:

```sh
export OS_AUTH_URL="https://stack.dhbw.cloud:5000"
export OS_USERNAME="pfisterer-cloud-lecture"
export OS_PASSWORD="ss2025"
export OS_PROJECT_ID="6c1ae45e04f24dc695d6f526fce253c6"
export OS_USER_DOMAIN_NAME="default"
# TODO: export OS_KEY="silasschroeder"
```

Load environment:
```bash
source env.sh
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Deploy Infrastructure with Versioning

#### Option A: Use Version Management Scripts (Recommended)

```bash
# Deploy specific version
./scripts/deploy-version.sh v1.0.0 1.0.0 apply

# Update application version only
./scripts/update-app-version.sh 1.1.0 <master_ip>

# Rollback to previous version
./scripts/rollback.sh v1.0.0

# List all versions
./scripts/list-versions.sh
```

#### Option B: Manual Terraform with Variables

```bash
# Plan deployment with specific versions
terraform plan -var="infrastructure_version=v1.0.0" -var="app_version=1.0.0"

# Apply with custom parameters
terraform apply -var="infrastructure_version=v1.1.0" -var="app_version=1.1.0" -var="app_replicas=5"
```

#### Option C: Enhanced Workflow (Interactive)

```bash
./workflow-enhanced.sh
```

### 4. Traditional Workflow (Original)

```bash
terraform apply
# Follow steps in workflow.sh
```

## Version Management

### Infrastructure Variables

- `infrastructure_version`: Version tag for infrastructure (default: "v1.0.0")
- `app_version`: Application version (default: "1.0.0")
- `worker_count`: Number of worker nodes (default: 2)
- `app_replicas`: Application replica count (default: 3)
- `min_replicas`: Minimum replicas for autoscaling (default: 1)
- `max_replicas`: Maximum replicas for autoscaling (default: 10)

### Available Scripts

- `deploy-version.sh`: Deploy/destroy specific infrastructure and app versions
- `update-app-version.sh`: Update application version without infrastructure changes
- `rollback.sh`: Rollback to a previous version
- `list-versions.sh`: Show all deployed versions and current status

## Application Features

The sample application includes:

- **Version Display**: Shows current version via `/version` endpoint
- **Health Check**: Available at `/health` endpoint
- **Persistent Storage**: Logs access to NFS-mounted volume
- **Horizontal Scaling**: Auto-scaling based on CPU usage
- **Load Balancer**: Service exposed via LoadBalancer

## Version History Tracking

Each deployment creates:
- `deployment-{version}.info`: Deployment metadata
- `k8s-entities-{version}.yaml`: Version-specific Kubernetes manifests
- Terraform state with version tags

## Rollback Process

1. List available versions: `./scripts/list-versions.sh`
2. Choose target version: `./scripts/rollback.sh v1.0.0`
3. Confirm rollback when prompted
4. System automatically destroys current and deploys target version

## Testing Versioning

1. Deploy initial version: `./scripts/deploy-version.sh v1.0.0 1.0.0 apply`
2. Update app: `./scripts/update-app-version.sh 1.1.0 <master_ip>`
3. Deploy new infrastructure: `./scripts/deploy-version.sh v1.1.0 1.2.0 apply`
4. Rollback: `./scripts/rollback.sh v1.0.0`
5. Verify: `./scripts/list-versions.sh`

## Architecture

- **OpenStack**: Cloud infrastructure provider
- **Terraform**: Infrastructure as Code with versioning
- **Salt**: Configuration management
- **Kubernetes (K3s)**: Container orchestration
- **Node.js**: Sample application with version support
- **NFS**: Persistent storage for stateful data

## Task Completion

### Task 1: Immutable Updates
- Demonstrated through Terraform infrastructure updates
- `terraform plan` shows changes
- `terraform apply` recreates instances with new versions

### Task 2: Versioned Infrastructure & Rollback
- Infrastructure versioning via Terraform variables
- Git-based version control
- Automated rollback scripts
- Resource cleanup for old versions

### Task 3: Application Installation & Versioning
- Kubernetes cluster with versioned application deployment
- Application version controlled via environment variables
- Automated deployment through infrastructure definition
- Version-specific Kubernetes manifests

## Troubleshooting

- Check master connectivity: `ping <master_ip>`
- Verify Salt keys: `ssh ubuntu@<master_ip> sudo salt-key -L`
- Check pod status: `ssh ubuntu@<master_ip> sudo kubectl get pods`
- View application logs: `ssh ubuntu@<master_ip> sudo kubectl logs -l app=sample-web-app`
