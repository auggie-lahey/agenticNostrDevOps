#!/bin/bash

# DevOps Workflow Script
# Sequential independent scripts - identity generation is separate from board creation

set -e

echo "DevOps Workflow..."
export config="config.yaml"
# Step 1: Check for existing keys, generate only if missing
if [ -f $config ] && grep -q "nsec:" $config && grep -q "npub:" $config; then
    echo "✓ Using existing identity"
else
    ./generate_nostr_keys.sh
fi
NSEC=$(yq e '.nostr.identity.private_key.nsec' $config -r)
NPUB=$(yq e '.nostr.identity.public_key.npub' $config -r)
echo $NPUB:$NSEC

# echo ""
# echo Step 2: Check if board exists, create only if missing
# if [ $(yq eval -r '.nostr.board.naddr' $config) != "null" ]; then
#     echo "✓ Using existing board"
# else
#     echo "Creating new board..."
#     ./create_kanban_board.sh "$NSEC" "$NPUB"
# fi

# echo ""
# echo Step 3: Check if cards exist, create if missing
# if [ $(yq eval -r '.nostr.board.cards_created' $config) != "null" ]; then
#     echo "✓ Using existing cards"
# else
#     echo "Creating sample cards..."
#     ./create_kanban_cards.sh "$NSEC" "$NPUB"
# fi

# # Step 4: Run tests
# echo ""
# echo "Testing board"
# ./test_relay_query.sh

# echo ""
# echo "Testing cards"
# ./test_card_creation.sh

# Step 5: Check for Git repository, create if missing
echo ""
echo "=== GIT REPOSITORY MANAGEMENT ==="
if [ $(yq eval -r '.nostr.repository.id' $config) != "null" ]; then
    echo "✓ Using existing Git repository"
    # REPO_NADDR=$(yq eval '.nostr.repository.naddr' $config -r)
    # REPO_URL=$(yq eval '.nostr.repository.gitworkshop_url' $config -r)
    # echo "Repository naddr: $REPO_NADDR"
    # echo "Git workshop URL: $REPO_URL"
else
    repo_name=$(yq e -r '.nostr.board.id' $config)
    ./create_nostr_git_repo.sh "$NSEC" $repo_name "DevOps Workflow Platform" "A comprehensive DevOps workflow platform built on Nostr technology"
fi

# # Step 6: Test Git repository
# echo ""
# echo "Testing Git repository..."
# if [ -f "./test_repo.sh" ]; then
#     ./test_repo.sh
# else
#     echo "Error: test_repo.sh not found"
#     exit 1
# fi

# # Step 7: Generate Highlighter URLs for debugging
# echo ""
# echo "=== HIGHLIGHTER DEBUG URLS ==="
# if [ -f $config ] && grep -q "naddr:" $config; then
#     NADDR=$(yq eval '.nostr.board.naddr' $config -r)
#     echo "Board:"
#     echo "https://highlighter.com/a/$NADDR"
    
#     # Show Git repository info if available
#     if [ -f $config ] && grep -q "  repository:" $config; then
#         echo ""
#         echo "Git Repository:"
#         REPO_NADDR=$(yq eval '.nostr.repository.naddr' $config -r)
#         REPO_URL=$(yq eval '.nostr.repository.gitworkshop_url' $config -r)
#         echo "Nostr naddr: $REPO_NADDR"
#         echo "Git workshop URL: $REPO_URL"
#     fi
    
#     echo ""
#     echo "Latest Cards:"
#     NPUB=$(yq eval '.nostr.identity.public_key.npub' $config -r)
#     NPUB_DECODED=$(./nak/nak decode "$NPUB")
#     CARD_EVENTS=$(./nak/nak req --author "$NPUB_DECODED" -k 30302 wss://relay.damus.io | jq -r '.id' | head -6)
    
#     CARD_NUM=1
#     for CARD_ID in $CARD_EVENTS; do
#         if [ -n "$CARD_ID" ] && [ "$CARD_ID" != "null" ]; then
#             CARD_TITLE=$(./nak/nak req --id "$CARD_ID" wss://relay.damus.io | jq -r '.tags[] | select(.[0] == "title")[1]' 2>/dev/null || echo "Card $CARD_NUM")
#             NEVENT_ENCODED=$(./nak/nak encode nevent --author "$NPUB_DECODED" --relay wss://relay.damus.io "$CARD_ID")
#             echo "$CARD_TITLE: https://highlighter.com/a/$NEVENT_ENCODED"
#             CARD_NUM=$((CARD_NUM + 1))
#         fi
#     done
# else
#     echo "No board found - run the script again to create one first"
# fi
