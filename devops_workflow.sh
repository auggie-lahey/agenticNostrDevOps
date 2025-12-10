#!/bin/bash

# DevOps Workflow Script
# Sequential independent scripts - identity generation is separate from board creation

set -e
echo nak version
nak --version

echo "DevOps Workflow..."
export config="config.yaml"
# Step 1: Check for existing keys, generate only if missing
if [ $(yq eval -r '.nostr.identity.private_key.nsec' $config) != "null" ]; then
    echo "✓ Using existing identity"
else
    ./generate_nostr_keys.sh
fi
export NSEC=$(yq e '.nostr.identity.private_key.nsec' $config -r)
export NPUB=$(yq e '.nostr.identity.public_key.npub' $config -r)
echo $NPUB:$NSEC
export NPUB_DECODED=$(nak decode "$NPUB" --pubkey)
export PUBKEY=$NPUB_DECODED
export QUERY_PUBKEY=$NPUB_DECODED
export CONSISTENT_PUBKEY=$NPUB_DECODED
export RELAY="wss://nos.lol"
export RELAY="wss://relay.damus.io"

echo ""
echo Step 2: Check if board exists, create only if missing
if [ $(yq eval -r '.nostr.board.naddr' $config) != "null" ]; then
    echo "✓ Using existing board"
else
    echo "Creating new board..."
    ./create_kanban_board.sh
fi

echo ""
echo Step 3: Check if cards exist, create if missing
if [ $(yq eval -r '.nostr.board.cards_created' $config) != "null" ]; then
    echo "✓ Using existing cards"
else
    echo "Creating sample cards..."
    ./create_kanban_cards.sh "$NSEC" "$NPUB"
fi

echo ""
echo Step 4: Run tests
echo "Testing board"
./test_relay_query.sh

echo ""
echo "Testing cards"
./test_card_creation.sh

# Step 5: Check for Git repository, create if missing
echo ""
echo "=== GIT REPOSITORY MANAGEMENT ==="
if [ $(yq eval -r '.nostr.repository.id' $config) != "null" ]; then
    echo "✓ Using existing Git repository"
    REPO_NADDR=$(yq eval '.nostr.repository.naddr' $config -r)
    REPO_URL=$(yq eval '.nostr.repository.gitworkshop_url' $config -r)
    echo "Repository naddr: $REPO_NADDR"
    echo "Git workshop URL: $REPO_URL"
else
    repo_name=$(yq e -r '.nostr.board.id' $config)
    ./create_nostr_git_repo.sh "$NSEC" $repo_name "DevOps Workflow Platform" "A comprehensive DevOps workflow platform built on Nostr technology"
fi

echo ""
echo Step 6: Test Git repository
./test_repo.sh

echo ""
echo Step 7: Generate Highlighter URLs for debugging
echo "=== HIGHLIGHTER DEBUG URLS ==="
NADDR=$(yq eval '.nostr.board.naddr' $config -r)
echo "Board:"
echo "https://highlighter.com/a/$NADDR"

# Show Git repository info if available
echo ""
echo "Git Repository:"
REPO_NADDR=$(yq eval '.nostr.repository.naddr' $config -r)
REPO_URL=$(yq eval '.nostr.repository.gitworkshop_url' $config -r)
echo "Nostr naddr: $REPO_NADDR"
echo "Git workshop URL: $REPO_URL"

echo ""
echo "Latest Cards:"
CARD_EVENTS=$(nak req --author "$NPUB_DECODED" -k 30302 $RELAY | jq -r '.id' | head -6)
echo $CARD_EVENTS
CARD_NUM=1
for CARD_ID in $CARD_EVENTS; do
    if [ -n "$CARD_ID" ] && [ "$CARD_ID" != "null" ]; then
        CARD_TITLE=$(nak req --id "$CARD_ID" $RELAY -q | jq -r '.tags[] | select(.[0] == "title")[1]' 2>/dev/null || echo "Card $CARD_NUM")
        NEVENT_ENCODED=$(nak encode nevent --author "$NPUB_DECODED" --relay $RELAY "$CARD_ID")
        echo "$CARD_TITLE: https://highlighter.com/a/$NEVENT_ENCODED"
        CARD_NUM=$((CARD_NUM + 1))
    fi
done

echo "move cards to in progress"
./update_kanban_cards.sh $CARD_TITLE "In Progress" "moving to inprogress"
# do work 
./do_work_make_pr.sh
# ./update_kanban_cards.sh $CARD_TITLE "Review" "moving to Review"
yq e '.nostr.board.kanbanstr_url' $config -r
yq eval -r '.nostr.identity.private_key.nsec' $config
