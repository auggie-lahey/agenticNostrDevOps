#!/bin/bash

# Enhanced update script that creates and outputs repository URL
set -e

# Path to your Nostr keys file
KEYS_FILE="/home/shepherd/Nextcloud/Projects/lab/agenticDevOps/nostr_keys.yaml"
NAK_PATH="/home/shepherd/Nextcloud/Projects/lab/agenticDevOps/nak"
REPO_SCRIPT="/home/shepherd/Nextcloud/Projects/lab/agenticDevOps/create_nostr_git_repo.sh"

# Extract user credentials
NSEC=$(grep "nsec:" "$KEYS_FILE" | awk '{print $2}' | tr -d '"')
PUBKEY=$(grep "npub:" "$KEYS_FILE" | awk '{print $2}' | tr -d '"')
BOARD_ID=$(grep "board:" -A 10 "$KEYS_FILE" | grep "id:" | awk '{print $2}' | tr -d '"')

# Column status mapping
declare -A COLUMN_STATUS=(
    ["Ideas"]="backlog"
    ["Backlog"]="backlog"
    ["In Progress"]="in-progress"
    ["Testing"]="in-review"
    ["Review"]="in-review"
    ["Done"]="done"
)

echo "=== Enhanced Card Update with Repository Management ==="
echo "Using Board ID: $BOARD_ID"
echo "Using Public Key: $PUBKEY"
echo ""

# Function to check if repository exists in YAML
check_repo_in_yaml() {
    if grep -q "repository_url:" "$KEYS_FILE"; then
        REPO_URL=$(grep "repository_url:" "$KEYS_FILE" | awk '{print $2}' | tr -d '"')
        echo "✅ Found existing repository in YAML: $REPO_URL"
        return 0
    else
        echo "ℹ️  No repository found in YAML - will create new one"
        return 1
    fi
}

# Function to update YAML with repository URL
update_yaml_with_repo() {
    local repo_url="$1"
    echo "📝 Updating YAML with repository URL..."
    
    # Add repository_url to the YAML file after the kanbanstr_url line
    sed -i "/kanbanstr_url:/a\\    repository_url: \"$repo_url\"" "$KEYS_FILE"
    echo "✅ Updated YAML with repository URL"
}

# Function to create new repository
create_repository() {
    echo "🔧 Creating new Nostr Git repository..."
    
    # Default repository information if not specified
    local repo_name="devops-workflow"
    local repo_title="DevOps Workflow Repository" 
    local repo_description="A comprehensive DevOps workflow management system with Kanban board integration"
    
    # Run the repository creation script and capture output
    REPO_OUTPUT=$("$REPO_SCRIPT" "$NSEC" "$repo_name" "$repo_title" "$repo_description" 2>&1)
    
    # Check if repository was created successfully (look for success indicators)
    if echo "$REPO_OUTPUT" | grep -q "✓ Git repository created"; then
        # Extract the repository URL from the output
        REPO_URL=$(echo "$REPO_OUTPUT" | grep "NAddr:" | awk '{print $2}' | head -1)
        
        if [ -n "$REPO_URL" ]; then
            echo "🎉 Repository created successfully!"
            echo "📦 Repository URL: $REPO_URL"
            
            # Update YAML with the new repository URL
            update_yaml_with_repo "$REPO_URL"
            
            return 0
        else
            echo "❌ Failed to extract repository URL from output"
            return 1
        fi
    else
        echo "❌ Repository creation failed"
        echo "Error: $REPO_OUTPUT"
        return 1
    fi
}

# Function to update a single card
update_card() {
    local card_title="$1"
    local target_status="$2"
    
    echo "🔄 Processing card: $card_title"
    echo "   Target status: $target_status"
    
    # Generate a consistent identifier based on the card title
    CARD_IDENTIFIER="card-$(echo "$card_title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')"
    
    echo "   Card identifier: $CARD_IDENTIFIER"
    
    # Create the update event
    UPDATE_RESULT=$($NAK_PATH event \
        --kind 30302 \
        -d "$CARD_IDENTIFIER" \
        -t "p:$BOARD_ID" \
        -t "s:$target_status" \
        -t "t:$card_title" \
        -c "Card: $card_title" \
        --sec "$NSEC" \
        wss://relay.damus.io 2>&1)
    
    if echo "$UPDATE_RESULT" | grep -q "SUCCESS"; then
        echo "   ✅ Update event sent successfully"
        
        # Verification step - query the relay to confirm the update
        echo "   🔍 Verifying card status on relay..."
        sleep 3  # Wait for event propagation
        
        VERIFICATION_RESULT=$($NAK_PATH req --author "$PUBKEY" -k 30302 wss://relay.damus.io | \
            jq --arg identifier "$CARD_IDENTIFIER" \
            'select(.tags[] | .[0] == "d" and .[1] == $identifier) | .tags[] | select(.[0] == "s")[1] // "UNMAPPED"' | \
            sort | uniq | tail -1 | tr -d '"')
        
        if [ "$VERIFICATION_RESULT" = "$target_status" ]; then
            echo "   ✅ VERIFIED: Card is now in status '$VERIFICATION_RESULT'"
            return 0
        else
            echo "   ⚠️  VERIFICATION MISMATCH: Expected '$target_status', got '$VERIFICATION_RESULT'"
            return 1
        fi
    else
        echo "   ❌ Failed to update card: $UPDATE_RESULT"
        return 1
    fi
}

# Main execution
main() {
    echo "Step 1: Checking for existing repository..."
    if ! check_repo_in_yaml; then
        echo ""
        echo "Step 2: Creating new repository..."
        if create_repository; then
            echo ""
        else
            echo "❌ Failed to create repository. Exiting."
            exit 1
        fi
    fi
    
    echo ""
    echo "Step 3: Updating cards..."
    echo ""
    
    # Update cards with their target statuses
    update_card "API Rate Limiting" "done"
    echo ""
    
    update_card "Database Migration" "in-review" 
    echo ""
    
    update_card "CI/CD Pipeline Setup" "in-progress"
    echo ""
    
    echo "🎉 Card update process completed!"
}

# Run main function
main "$@"
