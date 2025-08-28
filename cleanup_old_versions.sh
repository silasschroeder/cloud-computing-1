#!/bin/bash

echo "🧹 Cleaning up old filesystem-based version management"
echo "===================================================="

# List what will be removed
echo ""
echo "📋 Files/folders that will be removed:"
echo "   - versions/ folder (all version snapshots)"
echo "   - current_version.txt (replaced by Git branches/tags)"
echo "   - deployment_history.txt (replaced by Git log)"
echo ""

# Check if files exist
FILES_TO_REMOVE=""
if [ -d "versions" ]; then
    FILES_TO_REMOVE="$FILES_TO_REMOVE versions/"
fi
if [ -f "current_version.txt" ]; then
    FILES_TO_REMOVE="$FILES_TO_REMOVE current_version.txt"
fi
if [ -f "deployment_history.txt" ]; then
    FILES_TO_REMOVE="$FILES_TO_REMOVE deployment_history.txt"
fi

if [ -z "$FILES_TO_REMOVE" ]; then
    echo "✅ No old files found - system is already clean!"
    exit 0
fi

echo "🚨 WARNING: This will permanently delete the old version management files."
echo "            All version information is preserved in Git history."
echo ""
read -p "Continue with cleanup? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

# Remove old files
echo ""
echo "🗑️  Removing old files..."

if [ -d "versions" ]; then
    echo "   Removing versions/ folder..."
    rm -rf versions/
fi

if [ -f "current_version.txt" ]; then
    echo "   Removing current_version.txt..."
    rm -f current_version.txt
fi

if [ -f "deployment_history.txt" ]; then
    echo "   Removing deployment_history.txt..."
    rm -f deployment_history.txt
fi

# Commit the cleanup
echo ""
echo "📝 Committing cleanup to Git..."
git add .
git commit -m "Cleanup: Remove old filesystem-based version management

- Removed versions/ folder (replaced by Git tags)
- Removed current_version.txt (replaced by Git branches)
- Removed deployment_history.txt (replaced by Git log)

System now uses pure Git-based version management."

echo ""
echo "✅ Cleanup completed!"
echo ""
echo "📋 New Git-based workflow:"
echo "   Deploy: ./deploy_version.sh"
echo "   Status: ./version_status.sh"
echo "   Rollback: ./rollback.sh"
echo ""
echo "📚 See MIGRATION_TO_GIT.md for details"