# Migration to Git-based Version Management

## Overview
The deployment system has been migrated from filesystem-based version management (using the `versions` folder) to a pure Git-based approach using branches and tags.

## What Changed

### Old System (Filesystem-based)
- Versions stored in `versions/` folder
- Current version tracked in `versions/current_version.txt`
- Deployment history in `versions/deployment_history.txt`
- Each version had its own folder with files

### New System (Git-based)
- Versions managed with Git tags (e.g., `v1.0.0`, `v2.1.0`)
- Deploy branches created for each deployment (e.g., `deploy-v1.0.0`)
- All version history tracked in Git commits and tags
- No filesystem dependencies for version management

## Scripts Updated

### 1. `deploy_version.sh` (Already Git-based)
- Creates Git branch for each deployment
- Commits changes with version information
- Creates Git tags for releases
- Fully self-contained deployment

### 2. `version_status.sh` (Updated)
- Shows current Git branch and commit
- Lists available Git tags
- Shows deployment branches
- Displays recent deployment history from Git log
- Shows infrastructure status

### 3. `rollback.sh` (Updated)
- Lists available Git tags for rollback
- Checks out specific version tags
- Creates rollback branches with timestamps
- Handles infrastructure deployment for rollback version
- Maintains Git history of rollback operations

## Usage

### Deploy New Version
```bash
./deploy_version.sh
# Enter version when prompted (e.g., 1.2.0)
```

### Check Status
```bash
./version_status.sh
```

### Rollback to Previous Version
```bash
./rollback.sh
# Choose version tag or 'previous' for latest
```

### Manual Git Operations
```bash
# List all version tags
git tag --list "v*" --sort=-version:refname

# Switch to specific version
git checkout v1.0.0

# Create new deploy branch from tag
git checkout -b deploy-v1.0.0 v1.0.0

# View deployment history
git log --oneline --grep="Deploy version"
```

## Benefits of Git-based Approach

1. **No Filesystem Dependencies**: No need for `versions` folder
2. **Complete History**: Full deployment history in Git
3. **Branch Management**: Clear branch strategy for deployments
4. **Atomic Operations**: Git ensures consistency
5. **Remote Collaboration**: Works with Git remotes
6. **Standard Workflow**: Uses standard Git practices

## Cleanup

The following files/folders are no longer needed:
- `versions/` folder and all contents
- `current_version.txt`
- `deployment_history.txt`

These can be safely removed as all information is now tracked in Git.

## Migration Steps

1. All scripts have been updated to use Git
2. Old `versions` folder can be removed
3. Legacy tracking files can be deleted
4. Continue using same deployment workflow with updated scripts

The system is now fully Git-based and requires no filesystem-based version tracking.