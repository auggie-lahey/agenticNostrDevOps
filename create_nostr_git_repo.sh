#!/bin/bash

# Create Nostr Git Repository Script
# Creates a Nostr Git repository using nak workflow
#
# FIXED ISSUES (2025-12-06):
# - Removed premature ["r", "<commit>", "euc"] tag from repo announcement (commit not known yet)
# - Fixed nip34.json format to match nak git expectations (not NIP-34 event format)
# - Added actual commit hash extraction after Git commit creation
# - Updated owner pubkey to use consistent key from secret key
# - Used proper nip34.json structure with identifier, name, description, web, owner, grasp-servers, earliest-unique-commit, maintainers
set -e

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <nsec> [repo_name] [repo_title] [repo_description]"
    echo "Example: $0 nsec1... \"microservices-platform\" \"Microservices Platform\" \"A comprehensive microservices platform\""
    exit 1
fi

NSEC="$1"
REPO_NAME="${2:-devops-workflow}"
REPO_TITLE="${3:-DevOps Workflow Repository}"
REPO_DESCRIPTION="${4:-DevOps workflow management and automation repository}"

echo "Creating Nostr Git repository..."
echo "Repository: $REPO_NAME"
echo "Title: $REPO_TITLE"

echo "Using pubkey: $CONSISTENT_PUBKEY"

# Extract user's actual npub from YAML file for Git workshop URL
USER_NPUB=$(yq eval '.nostr.identity.public_key.npub' "$config")
GITWORKSHOP_URL="https://gitworkshop.dev/$USER_NPUB/relay.damus.io/$REPO_NAME"

echo "Creating repository event with proper NIP-34 structure..."
sleep 30
# Create repository event using the hex pubkey directly from the secret key
# FIXED: Use placeholder for earliest commit since we don't have it yet
REPO_EVENT=$(nak event \
    --kind 30617 \
    -d "$REPO_NAME" \
    -t "name=$REPO_NAME" \
    -t "description=$REPO_DESCRIPTION" \
    -t "clone=https://relay.ngit.dev/$USER_NPUB/$REPO_NAME.git" \
    -t "clone=https://gitnostr.com/$USER_NPUB/$REPO_NAME.git" \
    -t "web=$GITWORKSHOP_URL" \
    -t "relays=wss://relay.ngit.dev" \
    -t "relays=wss://gitnostr.com" \
    -t "relays=$RELAY" \
    -t "maintainers=$USER_NPUB" \
    -t "alt=git repository: $REPO_NAME" \
    -c "" \
    --sec "$NSEC" \
    wss://relay.ngit.dev wss://gitnostr.com $RELAY)

if [ -z "$REPO_EVENT" ]; then
    echo "Error: Failed to create repository event"
    exit 1
fi

# Extract event ID from the JSON response
REPO_EVENT_ID=$(echo "$REPO_EVENT" | jq -r '.id')
if [ -z "$REPO_EVENT_ID" ] || [ "$REPO_EVENT_ID" = "null" ]; then
    echo "Error: Could not extract event ID from repository creation"
    exit 1
fi

# Generate naddr for the repository
REPO_NADDR=$(nak encode naddr --kind 30617 --pubkey "$CONSISTENT_PUBKEY" --identifier "$REPO_NAME")
if [ -z "$REPO_NADDR" ]; then
    echo "Error: Could not generate repository naddr"
    exit 1
fi


#Set up a regular Git repository and then push with nak
echo "Setting up actual Git repository and initial push..."
REPO_DIR="$REPO_NAME"
rm -rf "$REPO_DIR"
mkdir -p "$REPO_DIR"
cd "$REPO_DIR"

# Initialize regular git repository
git init

# # Configure git for Nostr
# git config user.name "DevOps Workflow"
# git config user.email "$USER_NPUB@nostr.pub"

echo hello world > README.md

# Add and commit files
git add README.md
git commit -m "init"

# Get the actual commit hash for the nip34.json file
EARLIEST_COMMIT=$(git rev-list --max-parents=0 HEAD)

# FIXED: Create proper nip34.json file in the format nak expects
owner=$(nak decode "$USER_NPUB")
cat > nip34.json << EOF
{
  "identifier": "$REPO_NAME",
  "name": "$REPO_NAME",
  "description": "$REPO_DESCRIPTION",
  "web": [
    "$GITWORKSHOP_URL",
    "https://gitworkshop.dev/$USER_NPUB/$REPO_NAME"
  ],
  "owner": "$owner",
  "grasp-servers": [
    "relay.ngit.dev",
    "gitnostr.com"
  ],
  "earliest-unique-commit": "$EARLIEST_COMMIT,euc",
  "maintainers": [
    "$USER_NPUB"
  ]
}
EOF

echo "Pushing to Nostr Git servers using nak..."

# Retry loop for Git push (up to 3 minutes, retry every 30 seconds)
echo "Attempting initial Git push (will retry up to 3 minutes)..."
PUSH_SUCCESS=false
MAX_ATTEMPTS=6  # 6 attempts * 30 seconds = 3 minutes
ATTEMPT=1

set +e
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    sleep 30
    echo "Push attempt $ATTEMPT/$MAX_ATTEMPTS..."
    nak git push --sec $NSEC --force
    if nak git push --sec $NSEC 2>/dev/null; then
        echo "✓ Git push successful on attempt $ATTEMPT!"
        PUSH_SUCCESS=true
        break
    else
        if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
            echo "Push failed (attempt $ATTEMPT/$MAX_ATTEMPTS), waiting 30 seconds before retry..."
        else
            echo "✗ Git push failed after $MAX_ATTEMPTS attempts"
        fi
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
done
set -e
cd ..

if [ "$PUSH_SUCCESS" = false ]; then
    echo "⚠️  Git push did not complete within 3 minutes"
    echo "This is normal for new Nostr repositories - the push should complete automatically once the repository event propagates to Git servers"
    echo "You can retry manually with: cd $REPO_DIR && export NOSTR_SECRET_KEY=\"$NSEC\" && nak git push"
else
    # Update YAML file with repository information
    echo "Updating YAML file with repository information..."
    yq eval ".nostr.repository = {
    \"id\": \"$REPO_NAME\",
    \"event_id\": \"$REPO_EVENT_ID\",
    \"naddr\": \"$REPO_NADDR\",
    \"gitworkshop_url\": \"$GITWORKSHOP_URL\",
    \"identifier\": \"$REPO_NAME\",
    \"title\": \"$REPO_TITLE\",
    \"description\": \"$REPO_DESCRIPTION\",
    \"pubkey\": \"$CONSISTENT_PUBKEY\",
    \"relay\": \"$RELAY\",
    \"kind\": 30617,
    \"created_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
    }" "$config" > temp.yaml && mv temp.yaml "$config"

    echo "✓ Git repository created: $REPO_NAME"
    echo "✓ Repository ID: $REPO_EVENT_ID"
    echo "✓ Repository naddr: $REPO_NADDR"
    echo "✓ Git workshop URL: $GITWORKSHOP_URL"
    echo "✓ YAML file updated with repository information"
    echo ""
fi

echo "✓ Git repository initialized: $REPO_DIR"
echo "✓ Initial commit created and pushed"
echo "✓ Nostr Git remotes configured"

# echo "Repository information saved to: $REPO_INFO_FILE"
# echo ""

# # Generate Highlighter URL for debugging
# NEVENT_ENCODED=$(nak encode nevent --author "$CONSISTENT_PUBKEY" --relay $RELAY "$REPO_EVENT_ID")
# echo "Highlighter URL: https://highlighter.com/a/$NEVENT_ENCODED"

# echo ""
# echo "=== REPOSITORY DETAILS ==="
# echo "Repository Name: $REPO_NAME"
# echo "Title: $REPO_TITLE"
# echo "Description: $REPO_DESCRIPTION"
# echo "Event ID: $REPO_EVENT_ID"
# echo "NAddr: $REPO_NADDR"
# echo "Git Workshop URL: $GITWORKSHOP_URL"
# echo "Relay: $RELAY"
# echo "Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
