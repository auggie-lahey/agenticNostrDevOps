#!/bin/bash

# Create Kanban Board Script
# Independent script that creates a new board with columns only (no cards)

set -e


BOARD_ID="devops$RANDOM"
echo "Board ID: $BOARD_ID"

echo "Creating new DevOps kanban board..."
echo "Using pubkey from npub: $CONSISTENT_PUBKEY"

# Also extract pubkey from nsec for comparison
PUBKEY_FROM_NSEC_HEX=$(nak key public "$NSEC")
if [ "$CONSISTENT_PUBKEY" != "$PUBKEY_FROM_NSEC_HEX" ]; then
    echo "WARNING: nsec pubkey doesn't match npub pubkey!"
    echo "Event will be created with npub pubkey: $CONSISTENT_PUBKEY"
    echo "nsec-derived pubkey would be: $PUBKEY_FROM_NSEC_HEX"
else
    echo "Pubkeys match - using consistent pubkey"
fi

# Create the kanban board event (kind 30301) with columns using proper format
echo "Creating board structure..."
IDEAS_UUID=$(uuidgen)
BACKLOG_UUID=$(uuidgen)
IN_PROGRESS_UUID=$(uuidgen)
TESTING_UUID=$(uuidgen)
REVIEW_UUID=$(uuidgen)
DONE_UUID=$(uuidgen)

BOARD_EVENT=$(nak event \
    --kind 30301 \
    -d "$BOARD_ID" \
    -t "title=DevOps Workflow Board" \
    -t "description=DevOps workflow management board" \
    -t "alt=A board titled DevOps Workflow Board" \
    -t "col=$IDEAS_UUID;Ideas;0" \
    -t "col=$BACKLOG_UUID;Backlog;1" \
    -t "col=$IN_PROGRESS_UUID;In Progress;2" \
    -t "col=$TESTING_UUID;Testing;3" \
    -t "col=$REVIEW_UUID;Review;4" \
    -t "col=$DONE_UUID;Done;5" \
    --sec "$NSEC" \
    $RELAY)

if [ -z "$BOARD_EVENT" ]; then
    echo "Error: Failed to create board event"
    exit 1
fi

# Extract event ID from the JSON response
EVENT_ID=$(echo "$BOARD_EVENT" | jq -r '.id')
echo EVENT_ID: $EVENT_ID
if [ -z "$EVENT_ID" ] || [ "$EVENT_ID" = "null" ]; then
    echo "Error: Could not extract event ID from board creation"
    exit 1
fi

# Generate naddr (NIP-33 address for the board) using consistent pubkey
NADDR=$(nak encode naddr --kind 30301 --pubkey "$CONSISTENT_PUBKEY" --identifier "$BOARD_ID")
echo NADDR: $NADDR
if [ -z "$NADDR" ]; then
    echo "Error: Could not generate naddr"
    exit 1
fi

# Create Kanbanstr URL using consistent pubkey
KANBANSTR_URL="https://www.kanbanstr.com/#/board/${CONSISTENT_PUBKEY}/${BOARD_ID}"

# Update YAML file with board information
echo "Saving board information to YAML..."

# Create temp file with board info
cat >> "${config}" << EOF
  board:
    id: "$BOARD_ID"
    event_id: "$EVENT_ID"
    naddr: "$NADDR"
    kanbanstr_url: "$KANBANSTR_URL"
    columns:
      - name: "Ideas"
        color: "#9B59B6"
      - name: "Backlog"
        color: "#E74C3C"
      - name: "In Progress"
        color: "#F39C12"
      - name: "Testing"
        color: "#3498DB"
      - name: "Review"
        color: "#2ECC71"
      - name: "Done"
        color: "#95A5A6"
    created_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF

# Replace original YAML with temp file
echo "✓ Board created: $BOARD_ID"
echo "✓ Board URL: $KANBANSTR_URL"

# Step 5: Generate Highlighter URL for debugging
echo ""
echo "=== HIGHLIGHTER DEBUG URL ==="
echo "Board:"
echo "https://highlighter.com/a/$NADDR"
