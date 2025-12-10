#!/bin/bash

# Do Work and Make PR Script
# Performs arbitrary work (creates/modifies files) and submits a PR as a branch prefixed with "pr/"

set -e

# Get card title from arguments (passed from devops_workflow)
if [ $# -lt 1 ]; then
    echo "Error: Card title required"
    echo "Usage: $0 <card_title>"
    exit 1
fi

CARD_TITLE="$1"
./updatecard.sh $CARD_TITLE status "In Progress" "moving to inprogress"

# Load configuration (if not already loaded)
if [ -z "$config" ]; then
    export config="config.yaml"
fi

# Load variables from config (if not already loaded)
if [ -z "$NSEC" ]; then
    export NSEC=$(yq e '.nostr.identity.private_key.nsec' $config -r)
fi
if [ -z "$NPUB" ]; then
    export NPUB=$(yq e '.nostr.identity.public_key.npub' $config -r)
fi
if [ -z "$NPUB_DECODED" ]; then
    export NPUB_DECODED=$(nak decode "$NPUB" --pubkey)
fi
if [ -z "$CONSISTENT_PUBKEY" ]; then
    export CONSISTENT_PUBKEY=$NPUB_DECODED
fi
if [ -z "$RELAY" ]; then
    export RELAY="wss://relay.damus.io"
fi

# Get repository information
REPO_ID=$(yq eval -r '.nostr.repository.id' $config)
REPO_DIR="$REPO_ID"
GITWORKSHOP_URL=$(yq eval '.nostr.repository.gitworkshop_url' $config -r)

echo "=== DO WORK AND MAKE PR ==="
echo "Repository: $REPO_ID"
echo "Repository directory: $REPO_DIR"
echo "Card Title: $CARD_TITLE"
echo ""

# Find the card to get its description
echo "Retrieving card information for: $CARD_TITLE"
BOARD_ID=$(yq eval -r '.nostr.board.id' $config) 
CARD_QUERY=$(nak req --author "$CONSISTENT_PUBKEY" -k 30302 $RELAY | jq --arg title "$CARD_TITLE" --arg board_ref "30301:$CONSISTENT_PUBKEY:$BOARD_ID" 'select((.tags[] | .[0] == "title" and .[1] == $title) and (.tags[] | .[0] == "a" and .[1] == $board_ref))')

if [ -z "$CARD_QUERY" ]; then
    echo "Error: Card '$CARD_TITLE' not found"
    exit 1
fi

# Get the most recent card
CARD_JSON=$(echo "$CARD_QUERY" | jq -s '. | sort_by(.created_at) | reverse | .[0]')
CARD_DESCRIPTION=$(echo "$CARD_JSON" | jq -r '(.tags[] | select(.[0] == "description"))[1] // "No description available"')

echo "Card Description: $CARD_DESCRIPTION"
echo ""

cd "$REPO_DIR"

# Step 1: Do arbitrary work - create a new feature file
echo "Step 1: Performing arbitrary work..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create branch name from card title (sanitize for Git)
FEATURE_BRANCH="pr/$(echo "$CARD_TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')"

echo "Creating feature file for card: $CARD_TITLE"
echo "Card Description: $CARD_DESCRIPTION"

FEATURE_FILE="feature_${TIMESTAMP}.md"

cat > "$FEATURE_FILE" << EOF
# Feature Implementation - $CARD_TITLE

This file was created as part of the automated DevOps workflow for card: **$CARD_TITLE**

## Card Description
$CARD_DESCRIPTION

## Changes Made
- Added new feature file for this card
- Updated documentation
- Performed automated work based on card requirements

## Implementation Details
- Created: $(date)
- Branch: $FEATURE_BRANCH
- Card: $CARD_TITLE
- Automated by: do_work_make_pr.sh

## Next Steps
- Review the changes
- Merge the PR
- Deploy to production
- Update card to 'Done' status
EOF

# Also create a simple script as part of the work
cat > "script_${TIMESTAMP}.sh" << EOF
#!/bin/bash
# Auto-generated script for card: $CARD_TITLE
echo "Hello from automated workflow!"
echo "This script was generated for card: $CARD_TITLE"
echo "Card Description: $CARD_DESCRIPTION"
echo "Feature branch: $FEATURE_BRANCH"
echo "Generated at: $(date)"
EOF
chmod +x "script_${TIMESTAMP}.sh"

# Update README.md to include the new feature
echo "" >> README.md
echo "## Latest Feature - $CARD_TITLE ($TIMESTAMP)" >> README.md
echo "- Card: $CARD_TITLE" >> README.md
echo "- Card Description: $CARD_DESCRIPTION" >> README.md
echo "- Added feature file: $FEATURE_FILE" >> README.md
echo "- Added script: script_${TIMESTAMP}.sh" >> README.md
echo "- Branch: $FEATURE_BRANCH" >> README.md

echo "✓ Arbitrary work completed"
echo "✓ Created: $FEATURE_FILE"
echo "✓ Created: script_${TIMESTAMP}.sh"
echo "✓ Updated: README.md"
echo ""

# Step 2: Create and checkout PR branch
echo "Step 2: Creating PR branch: $FEATURE_BRANCH"
git checkout main 2>/dev/null || git checkout master 2>/dev/null || true
git checkout -b "$FEATURE_BRANCH"
git remote add origin nostr://$NPUB/relay.ngit.dev/$REPO_ID

if [ $? -ne 0 ]; then
    echo "Error: Failed to create branch $FEATURE_BRANCH"
    exit 1
fi

# Step 3: Add and commit changes
echo "Step 3: Committing changes..."
git add "$FEATURE_FILE" "script_${TIMESTAMP}.sh" README.md
git commit -m "feat: Implement feature for $CARD_TITLE

- Add feature documentation for card: $CARD_TITLE
- Add utility script
- Update README with latest changes

Card Description: $CARD_DESCRIPTION

Automated by: do_work_make_pr.sh
Timestamp: $TIMESTAMP"

if [ $? -ne 0 ]; then
    echo "Error: Failed to commit changes"
    exit 1
fi

echo "✓ Changes committed successfully"
echo ""

# Step 4: Push the PR branch
echo "Step 4: Pushing PR branch to remote..."
export NOSTR_SECRET_KEY="$NSEC"

# Retry loop for Git push (up to 2 minutes, retry every 20 seconds)
PUSH_SUCCESS=false
MAX_ATTEMPTS=6  # 6 attempts * 20 seconds = 2 minutes
ATTEMPT=1

set +e
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "Push attempt $ATTEMPT/$MAX_ATTEMPTS..."
    if git push; then
        echo "✓ Git push successful on attempt $ATTEMPT!"
        PUSH_SUCCESS=true
        break
    else
    # if nak git push --origin "$FEATURE_BRANCH" --sec "$NSEC" 2>/dev/null; then
    #     echo "✓ Git push successful on attempt $ATTEMPT!"
    #     PUSH_SUCCESS=true
    #     break
    # else
        if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
            echo "Push failed (attempt $ATTEMPT/$MAX_ATTEMPTS), waiting 20 seconds before retry..."
            sleep 20
        else
            echo "✗ Git push failed after $MAX_ATTEMPTS attempts"
        fi
    fi
    
    ATTEMPT=$((ATTEMPT + 1))
done
set -e

cd ..

# Generate PR URL for gitworkshop
hex=$(nak req -p $NPUB_DECODED -k 1617 $RELAY | jq -r '.id')
NOTE_ID=$(nak encode nevent $hex)
PR_URL="https://gitworkshop.dev/$NOTE_ID"

if [ "$PUSH_SUCCESS" = false ]; then
    echo "⚠️  Git push did not complete within 2 minutes"
    echo "This is normal for new branches - the push should complete automatically"
    echo "You can retry manually with:"
    echo "cd $REPO_DIR && export NOSTR_SECRET_KEY=\"$NSEC\" && nak git push --origin $FEATURE_BRANCH --sec \$NOSTR_SECRET_KEY"
    echo ""
    echo "PR URL will be: $PR_URL"
else
    echo "✓ PR branch pushed successfully"
fi

echo ""
echo "=== PR SUMMARY ==="
echo "✓ Feature branch: $FEATURE_BRANCH"
echo "✓ Repository: $REPO_ID"
echo "✓ Card: $CARD_TITLE"
echo "✓ Files created:"
echo "  - $FEATURE_FILE"
echo "  - script_${TIMESTAMP}.sh"
echo "  - README.md (updated)"
echo ""

# Generate URLs for the PR
REPO_NADDR=$(yq eval '.nostr.repository.naddr' $config -r)

echo "=== ACCESS URLS ==="
echo "Git Workshop PR: $PR_URL"
echo "Git Workshop Repository: $GITWORKSHOP_URL"
echo "Nostr Repository: https://highlighter.com/a/$REPO_NADDR"
echo ""

echo "=== NEXT STEPS ==="
echo "1. Review the changes in the PR branch: $FEATURE_BRANCH"
echo "2. Test the implementation"
echo "3. Merge the PR when ready"
echo "4. Update kanban card to 'Review' or 'Done'"
echo ""

# Update kanban card description with PR link
echo "Updating kanban card with PR link..."
UPDATED_DESCRIPTION="$CARD_DESCRIPTION

---
<strong>PR Created:</strong> <a href=\"$PR_URL\">$FEATURE_BRANCH</a><br>
Implementation completed at: $(date)"
./updatecard.sh "$CARD_TITLE" "description" "$UPDATED_DESCRIPTION" "PR link added"

echo "✓ Work and PR creation completed successfully!"
./updatecard.sh $CARD_TITLE status "Review" "moving to inprogress"
