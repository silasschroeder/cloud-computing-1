#!/bin/bash

echo "🚀 Git-based Version Status"
echo "=========================="

# Show current branch
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "📍 Current branch: $CURRENT_BRANCH"

# Show current commit
CURRENT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
echo "📝 Current commit: $CURRENT_COMMIT"

# If on a deploy branch, extract version
if [[ "$CURRENT_BRANCH" =~ ^deploy-v.* ]]; then
    CURRENT_VERSION=$(echo "$CURRENT_BRANCH" | sed 's/deploy-v//')
    echo "🏷️  Current version: $CURRENT_VERSION"
fi

echo ""

# Show available version tags
echo "📋 Available version tags:"
TAGS=$(git tag --list "v*" --sort=-version:refname 2>/dev/null)
if [ -n "$TAGS" ]; then
    echo "$TAGS" | head -10  # Show last 10 versions
    TAG_COUNT=$(echo "$TAGS" | wc -l)
    if [ "$TAG_COUNT" -gt 10 ]; then
        echo "... and $((TAG_COUNT - 10)) more versions"
    fi
else
    echo "No version tags found"
fi

echo ""

# Show deployment branches
echo "🌿 Deploy branches:"
DEPLOY_BRANCHES=$(git branch -a | grep "deploy-v" | sed 's/.*\///g' | sed 's/^[* ] //' | sort -V)
if [ -n "$DEPLOY_BRANCHES" ]; then
    echo "$DEPLOY_BRANCHES"
else
    echo "No deploy branches found"
fi

echo ""

# Show recent commits with version tags
echo "📚 Recent deployment history:"
git log --oneline --decorate --grep="Deploy version" -10 2>/dev/null || echo "No deployment commits found"

echo ""

# Show infrastructure status if terraform state exists
if [ -f "terraform.tfstate" ]; then
    echo "🏗️  Infrastructure status:"
    MASTER_IP=$(grep -A 3 "mjcs2-k8s-master" terraform.tfstate 2>/dev/null | grep "access_ip_v4" | cut -d'"' -f4)
    if [ -n "$MASTER_IP" ]; then
        echo "   Master IP: $MASTER_IP"
        echo "   Status: Infrastructure appears to be deployed"
    else
        echo "   Status: No active infrastructure found"
    fi
else
    echo "🏗️  Infrastructure status: No terraform state found"
fi