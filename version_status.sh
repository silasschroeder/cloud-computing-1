#!/bin/bash

# Show current version
if [ -f "versions/current_version.txt" ]; then
    CURRENT=$(cat versions/current_version.txt)
    echo "Current version: $CURRENT"
    
    # Show app version from package.json
    if [ -f "sample-app/package.json" ]; then
        APP_VERSION=$(grep '"version"' sample-app/package.json | cut -d'"' -f4)
        echo "App version: $APP_VERSION"
    fi
else
    echo "No version deployed yet"
fi

echo ""

# Show available versions
echo "Available versions:"
if [ -d "versions" ]; then
    ls -1 versions/ | grep -v "current_version.txt" | grep -v "deployment_history.txt"
else
    echo "No versions found"
fi

echo ""

# Show deployment history
if [ -f "versions/deployment_history.txt" ]; then
    echo "Deployment history:"
    cat versions/deployment_history.txt
fi