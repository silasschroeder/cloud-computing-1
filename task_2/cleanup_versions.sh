#!/bin/bash

echo "Git Version Cleanup Tool"
echo "============================"

# Function to show available versions
show_versions() {
    echo "Available version tags:"
    TAGS=$(git tag --list "v*" --sort=-version:refname 2>/dev/null)
    if [ -n "$TAGS" ]; then
        echo "$TAGS"
        echo ""
        echo "Total: $(echo "$TAGS" | wc -l) versions"
    else
        echo "No version tags found"
        return 1
    fi
}

# Function to show deploy branches
show_branches() {
    echo ""
    echo "Deploy branches:"
    BRANCHES=$(git branch -a | grep -E "(deploy-v|rollback-to)" | sed 's/.*\///g' | sed 's/^[* ] //' | sort -u)
    if [ -n "$BRANCHES" ]; then
        echo "$BRANCHES"
        echo ""
        echo "Total: $(echo "$BRANCHES" | wc -l) deploy/rollback branches"
    else
        echo "No deploy/rollback branches found"
    fi
}

# Function to validate version format
validate_version() {
    local version="$1"
    if [[ ! "$version" =~ ^v[0-9]+(\.[0-9]+)*$ ]]; then
        echo "Invalid version format. Use format: v1.0.0, v2.1, etc."
        return 1
    fi
    
    if ! git tag --list | grep -q "^${version}$"; then
        echo "Version tag $version not found"
        return 1
    fi
    
    return 0
}

# Function to delete specific version
delete_version() {
    local version="$1"
    
    if ! validate_version "$version"; then
        return 1
    fi
    
    echo ""
    echo "🚨 WARNING: This will permanently delete version $version"
    echo "   - Git tag $version will be removed"
    echo "   - Associated branches will be deleted"
    echo "   - This action cannot be undone"
    echo ""
    read -p "Are you sure you want to delete version $version? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        echo "Deletion cancelled"
        return 0
    fi
    
    echo ""
    echo "🗑️  Deleting version $version..."
    
    # Delete the tag
    git tag -d "$version"
    echo "Deleted tag $version"
    
    # Delete associated deploy branch if it exists
    local deploy_branch="deploy-$version"
    if git show-ref --verify --quiet refs/heads/$deploy_branch; then
        git branch -D "$deploy_branch"
        echo "Deleted branch $deploy_branch"
    fi
    
    # Delete associated rollback branches
    local rollback_branches=$(git branch | grep "rollback-to-$(echo $version | sed 's/v//')" | sed 's/^[* ] //')
    if [ -n "$rollback_branches" ]; then
        echo "$rollback_branches" | while read branch; do
            if [ -n "$branch" ]; then
                git branch -D "$branch"
                echo "Deleted rollback branch $branch"
            fi
        done
    fi
    
    echo ""
    echo "Version $version has been completely removed"
}

# Function to delete versions older than specified version
delete_older_versions() {
    local keep_version="$1"
    
    if ! validate_version "$keep_version"; then
        return 1
    fi
    
    # Get all versions and find which ones are older
    local all_versions=$(git tag --list "v*" --sort=version:refname)
    local versions_to_delete=""
    
    for version in $all_versions; do
        # Compare versions (simple string comparison for now)
        if [[ "$version" < "$keep_version" ]]; then
            versions_to_delete="$versions_to_delete $version"
        fi
    done
    
    if [ -z "$(echo $versions_to_delete | xargs)" ]; then
        echo "ℹ️  No versions older than $keep_version found"
        return 0
    fi
    
    echo ""
    echo "🚨 WARNING: This will permanently delete all versions older than $keep_version"
    echo ""
    echo "Versions to be deleted:"
    for version in $versions_to_delete; do
        echo "   - $version"
    done
    echo ""
    echo "Version $keep_version and newer will be preserved"
    echo ""
    read -p "Are you sure you want to delete these versions? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        echo "Deletion cancelled"
        return 0
    fi
    
    echo ""
    echo "🗑️  Deleting older versions..."
    
    local deleted_count=0
    for version in $versions_to_delete; do
        echo "Deleting $version..."
        
        # Delete the tag
        git tag -d "$version" > /dev/null 2>&1
        
        # Delete associated deploy branch
        local deploy_branch="deploy-$version"
        if git show-ref --verify --quiet refs/heads/$deploy_branch; then
            git branch -D "$deploy_branch" > /dev/null 2>&1
        fi
        
        # Delete associated rollback branches
        local rollback_branches=$(git branch | grep "rollback-to-$(echo $version | sed 's/v//')" | sed 's/^[* ] //')
        if [ -n "$rollback_branches" ]; then
            echo "$rollback_branches" | while read branch; do
                if [ -n "$branch" ]; then
                    git branch -D "$branch" > /dev/null 2>&1
                fi
            done
        fi
        
        deleted_count=$((deleted_count + 1))
        echo "Deleted $version"
    done
    
    echo ""
    echo "Successfully deleted $deleted_count versions older than $keep_version"
}

# Function to delete all deploy/rollback branches
cleanup_branches() {
    echo ""
    echo "WARNING: This will delete ALL deploy and rollback branches"
    echo "   - All branches starting with 'deploy-v' will be deleted"
    echo "   - All branches starting with 'rollback-to' will be deleted"
    echo "   - Version tags will be preserved"
    echo ""
    read -p "Are you sure you want to cleanup all deploy/rollback branches? (yes/no): " CONFIRM
    
    if [ "$CONFIRM" != "yes" ]; then
        echo "Cleanup cancelled"
        return 0
    fi
    
    echo ""
    echo "🧹 Cleaning up branches..."
    
    # Get current branch to avoid deleting it
    local current_branch=$(git branch --show-current)
    local deleted_count=0
    
    # Delete deploy branches
    local deploy_branches=$(git branch | grep "deploy-v" | sed 's/^[* ] //')
    if [ -n "$deploy_branches" ]; then
        echo "$deploy_branches" | while read branch; do
            if [ -n "$branch" ] && [ "$branch" != "$current_branch" ]; then
                git branch -D "$branch"
                echo "Deleted deploy branch $branch"
                deleted_count=$((deleted_count + 1))
            fi
        done
    fi
    
    # Delete rollback branches
    local rollback_branches=$(git branch | grep "rollback-to" | sed 's/^[* ] //')
    if [ -n "$rollback_branches" ]; then
        echo "$rollback_branches" | while read branch; do
            if [ -n "$branch" ] && [ "$branch" != "$current_branch" ]; then
                git branch -D "$branch"
                echo "Deleted rollback branch $branch"
                deleted_count=$((deleted_count + 1))
            fi
        done
    fi
    
    echo ""
    if [ "$deleted_count" -gt 0 ]; then
        echo "Cleaned up deployment branches"
    else
        echo "ℹ No deployment branches to clean up"
    fi
}

# Main menu
while true; do
    echo ""
    echo "🎯 What would you like to do?"
    echo ""
    echo "1) Show all versions and branches"
    echo "2) Delete a specific version"
    echo "3) Delete all versions older than X"
    echo "4) Cleanup deploy/rollback branches only"
    echo "5) Exit"
    echo ""
    read -p "Choose option (1-5): " CHOICE
    
    case $CHOICE in
        1)
            echo ""
            show_versions
            show_branches
            ;;
        2)
            echo ""
            show_versions
            if [ $? -eq 0 ]; then
                echo ""
                read -p "Enter version to delete (e.g., v1.0.0): " VERSION
                if [ -n "$VERSION" ]; then
                    delete_version "$VERSION"
                fi
            fi
            ;;
        3)
            echo ""
            show_versions
            if [ $? -eq 0 ]; then
                echo ""
                read -p "Keep version X and newer (e.g., v2.0.0): " KEEP_VERSION
                if [ -n "$KEEP_VERSION" ]; then
                    delete_older_versions "$KEEP_VERSION"
                fi
            fi
            ;;
        4)
            show_branches
            cleanup_branches
            ;;
        5)
            echo ""
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option. Please choose 1-5."
            ;;
    esac
done