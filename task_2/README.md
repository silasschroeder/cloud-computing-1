# Cloud-Computing-und-Big-Data

This repository contains infrastructure as code and automation scripts for deploying a Kubernetes-based stateful application to OpenStack cloud infrastructure.

## Prerequisites

- OpenStack credentials configured
- Git repository access
- OpenTofu/Terraform installed
- SSH access to deployed instances

## Quick Start

1. Configure OpenStack environment (credentials are embedded in scripts)
2. Deploy a new version: `./deploy_version.sh`
3. Rollback if needed: `./rollback.sh`
4. Clean up when done: `./destroy.sh`

## Shell Scripts Usage

### `deploy_version.sh` - Deploy New Infrastructure Version

Deploys a new versioned infrastructure with a containerized application to OpenStack and Kubernetes.

**Usage:**
```bash
./deploy_version.sh
```

**What it does:**
1. Prompts for infrastructure version number (e.g., `1.0.0`)
2. Prompts for app version number (for Docker image `silasschroeder/stateful-app:v{version}`)
3. Creates a new Git branch `deploy-v{version}`
4. Generates Kubernetes manifests (`k8s-app.yaml`)
5. Commits changes and creates a Git tag `v{version}`
6. Deploys infrastructure using OpenTofu
7. Installs K3s Kubernetes on the master node
8. Deploys the stateful application with persistent storage
9. Sets up NFS for shared storage between pods
10. Provides access URL for the deployed application

**Output:**
- New Git branch and tag for version tracking
- Running Kubernetes cluster with your application
- Application accessible via HTTP on the master node

**Example:**
```bash
$ ./deploy_version.sh
Enter infrastructure version number: 2.1.0
Enter app version (for silasschroeder/stateful-app): 1.5.0
# Deploys infrastructure v2.1.0 with app v1.5.0
# Application will be available at http://{master_ip}:{nodeport}
```

---

### `rollback.sh` - Rollback to Previous Version

Rolls back infrastructure and application to a previously deployed version using Git tags.

**Usage:**
```bash
./rollback.sh
```

**What it does:**
1. Shows available version tags from Git history
2. Prompts for target version (or type `previous` for latest)
3. Destroys current infrastructure
4. Commits any pending changes to current branch
5. Switches to the selected version tag
6. Creates a new rollback branch
7. Redeploys infrastructure and application from that version
8. Provides access information for the rolled-back application

**Interactive Options:**
- Enter specific version: `v1.2.0`
- Use previous version: `previous`

**Example:**
```bash
$ ./rollback.sh
Available versions:
v2.1.0
v2.0.0
v1.5.0
v1.0.0

Current branch: deploy-v2.1.0
Enter version tag to rollback to (e.g., v1.0.0) or 'previous' for the last version: v2.0.0
# Rolls back to infrastructure and app from v2.0.0
```

---

### `destroy.sh` - Destroy Infrastructure

Completely destroys all deployed infrastructure resources.

**Usage:**
```bash
./destroy.sh
```

**What it does:**
1. Loads OpenStack environment variables
2. Initializes OpenTofu with latest configuration
3. Destroys all infrastructure resources using `tofu destroy`
4. Cleans up local inventory files
5. Confirms destruction completion

**Warning:** This permanently deletes all infrastructure resources. Use with caution.

**Example:**
```bash
$ ./destroy.sh
Starting infrastructure destruction...
Initializing OpenTofu...
Destroying infrastructure with OpenTofu...
# All resources are destroyed
Infrastructure destruction completed!
```

---

### `cleanup_versions.sh` - Git Version Management

Interactive tool for managing Git branches and tags created by the deployment system.

**Usage:**
```bash
./cleanup_versions.sh
```

**Features:**
1. **Show all versions and branches** - Lists all version tags and deployment branches
2. **Delete specific version** - Remove a single version tag and associated branches
3. **Delete older versions** - Remove all versions older than a specified version
4. **Cleanup deploy/rollback branches** - Remove all deployment branches while keeping tags
5. **Exit** - Close the tool

**Interactive Menu:**
```
What would you like to do?

1) Show all versions and branches
2) Delete a specific version
3) Delete all versions older than X
4) Cleanup deploy/rollback branches only
5) Exit

Choose option (1-5):
```

**Use Cases:**
- **Regular maintenance:** Remove old deployment branches to keep repository clean
- **Storage cleanup:** Delete obsolete versions to reduce repository size
- **Version management:** Keep only recent versions for rollback purposes

**Example:**
```bash
$ ./cleanup_versions.sh
# Interactive menu appears
# Choose option 3 to delete versions older than v2.0.0
# This removes v1.0.0, v1.5.0 but keeps v2.0.0, v2.1.0
```

## Workflow Examples

### Deploy New Version
```bash
# Deploy version 3.0.0 with app version 2.1.0
./deploy_version.sh
# Follow prompts
# Access application at provided URL
```

### Rollback After Issue
```bash
# If current version has problems, rollback
./rollback.sh
# Select previous working version
# Application restored to previous state
```

### Clean Up Old Versions
```bash
# Periodically clean up old versions
./cleanup_versions.sh
# Choose option 3: Delete versions older than current
# Keep repository tidy
```

### Complete Teardown
```bash
# When project is complete
./destroy.sh
# All resources removed from OpenStack
```
