#!/bin/bash

# Simple Card Update Script
# Creates/updates a card with a consistent identifier based on title

set -e

# Check arguments
if [ $# -lt 4 ]; then
    echo "Usage: $0 <nsec> <npub> <card_title> <new_status>"
    echo "Example: $0 nsec1... npub1... \"Database Migration\" \"Backlog\""
    echo ""
    echo "Available statuses: Ideas, Backlog, In Progress, Testing, Review, Done, To Do"
    exit 1
fi

NSEC="$1"
NPUB="$2"
CARD_TITLE="$3"
NEW_STATUS="$4"

NAK_PATH="./nak/nak"

echo "Simple card update..."
echo "Card: $CARD_TITLE"
echo "New Status: $NEW_STATUS"

# Check if nak binary exists
if [ ! -f "$NAK_PATH" ]; then
    echo "Error: nak binary not found at $NAK_PATH"
    exit 1
fi

# Check if YAML file exists
YAML_FILE="nostr_keys.yaml"
if [ ! -f "$YAML_FILE" ]; then
    echo "Error: $YAML_FILE not found"
    exit 1
fi

# Extract board information
BOARD_ID=$(grep -A1 "board:" "$YAML_FILE" | grep "id:" | awk '{print $2}' | sed 's/^"//;s/"$//')
if [ -z "$BOARD_ID" ]; then
    echo "Error: Board ID not found in YAML file"
    exit 1
fi

# Extract pubkey from npub
CONSISTENT_PUBKEY=$($NAK_PATH decode "$NPUB")
if [ -z "$CONSISTENT_PUBKEY" ]; then
    echo "Error: Could not decode npub to pubkey"
    exit 1
fi

echo "Board ID: $BOARD_ID"

# Generate a consistent identifier based on the card title
# This ensures the same card always gets the same identifier
CARD_IDENTIFIER="card-$(echo "$CARD_TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')"

echo "Using consistent identifier: $CARD_IDENTIFIER"

# Create/update the card event (replaceable event with consistent identifier)
echo "Creating/updating card with status: $NEW_STATUS"
UPDATED_EVENT=$($NAK_PATH event \
    --kind 30302 \
    -d "$CARD_IDENTIFIER" \
    -t "a=30301:$CONSISTENT_PUBKEY:$BOARD_ID" \
    -t "title=$CARD_TITLE" \
    -t "description=$CARD_TITLE task" \
    -t "alt=A card titled $CARD_TITLE" \
    -t "priority=medium" \
    -t "rank=0" \
    -t "s=$NEW_STATUS" \
    -c "Task: $CARD_TITLE" \
    --sec "$NSEC" \
    $RELAY)

if [ -n "$UPDATED_EVENT" ]; then
    echo "✓ Card updated/created successfully!"
    echo "✓ Event ID: $(echo "$UPDATED_EVENT" | jq -r '.id')"
else
    echo "✗ Failed to update/create card"
    exit 1
fi

# Generate Highlighter URL for debugging
NEVENT_ENCODED=$($NAK_PATH encode nevent --author "$CONSISTENT_PUBKEY" --relay $RELAY "$(echo "$UPDATED_EVENT" | jq -r '.id')")
echo ""
echo "Highlighter URL: https://highlighter.com/a/$NEVENT_ENCODED"

# Verification: Query the relay to confirm the card was moved
echo ""
echo "=== VERIFICATION: Checking card status on relay ==="
echo "Querying relay to confirm '$CARD_TITLE' is now in '$NEW_STATUS'..."

# Wait a moment for the event to propagate
sleep 2

# Query the card by our consistent identifier
VERIFICATION_RESULT=$($NAK_PATH req --author "$CONSISTENT_PUBKEY" -k 30302 $RELAY | jq --arg identifier "$CARD_IDENTIFIER" 'select(.tags[] | .[0] == "d" and .[1] == $identifier) | .tags[] | select(.[0] == "s")[1] // "UNMAPPED"' | sort | uniq | tail -1 | tr -d '"')

if [ "$VERIFICATION_RESULT" = "$NEW_STATUS" ]; then
    echo "✅ VERIFICATION SUCCESSFUL: Card is now in '$NEW_STATUS' column"
elif [ -z "$VERIFICATION_RESULT" ]; then
    echo "⚠️  VERIFICATION WARNING: Could not find card on relay (may still be propagating)"
else
    echo "❌ VERIFICATION FAILED: Card found in '$VERIFICATION_RESULT', expected '$NEW_STATUS'"
    echo "   This could be due to relay propagation delay or multiple card versions"
fi

echo ""
echo "Card identifier used: $CARD_IDENTIFIER"
echo "Expected status: $NEW_STATUS"
echo "Found status: ${VERIFICATION_RESULT:-"NOT_FOUND"}"
