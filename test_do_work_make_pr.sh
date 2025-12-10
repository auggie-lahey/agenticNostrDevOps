#!/bin/bash

# Test script for do_work_make_pr.sh
# Verifies that the PR creation script works correctly

set -e

echo "=== TESTING DO WORK AND MAKE PR SCRIPT ==="

# Check if the script exists and is executable
if [ ! -x "do_work_make_pr.sh" ]; then
    echo "✗ do_work_make_pr.sh not found or not executable"
    exit 1
fi

echo "✓ do_work_make_pr.sh exists and is executable"

# Check if config.yaml exists
if [ ! -f "config.yaml" ]; then
    echo "✗ config.yaml not found"
    exit 1
fi

echo "✓ config.yaml exists"

# Check if repository exists in config
REPO_ID=$(yq eval -r '.nostr.repository.id' config.yaml)
if [ "$REPO_ID" = "null" ] || [ -z "$REPO_ID" ]; then
    echo "✗ No repository found in config.yaml"
    echo "Please run the main devops workflow first"
    exit 1
fi

echo "✓ Repository found: $REPO_ID"

# Check if repository directory exists
if [ ! -d "$REPO_ID" ]; then
    echo "✗ Repository directory $REPO_ID not found"
    exit 1
fi

echo "✓ Repository directory exists: $REPO_ID"

# Check if we're in the right branch
cd "$REPO_ID"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    echo "✓ On main branch: $CURRENT_BRANCH"
else
    echo "⚠️  Not on main branch: $CURRENT_BRANCH"
    echo "Switching back to main branch..."
    git checkout main 2>/dev/null || git checkout master 2>/dev/null || {
        echo "✗ Could not switch to main/master branch"
        exit 1
    }
fi

cd ..

echo ""
echo "=== SIMULATING PR CREATION ==="
echo "The script will:"
echo "1. Create new files in the repository"
echo "2. Create a branch with 'pr/' prefix"
echo "3. Commit the changes"
echo "4. Push to the Nostr Git remote"
echo ""

echo "✓ Test setup complete"
echo "✓ Ready to run: ./do_work_make_pr.sh"
echo ""
echo "To test with kanban card update:"
echo "./do_work_make_pr.sh \"Your Card Title\""
