#!/bin/bash

# Create Kanban Cards Script
# Creates sample DevOps cards for the kanban board

set -e

# Check arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <nsec> <npub>"
    exit 1
fi

NSEC="$1"
NPUB="$2"

echo "Creating kanban cards..."
# Extract board information
BOARD_ID=$(yq e -r '.nostr.board.id' $config)
if [ -z "$BOARD_ID" ]; then
    echo "Error: Board ID not found in YAML file"
    exit 1
fi

# Extract pubkey from npub (consistent with event creation)
CONSISTENT_PUBKEY=$(nak decode "$NPUB")
if [ -z "$CONSISTENT_PUBKEY" ]; then
    echo "Error: Could not decode npub to pubkey"
    exit 1
fi

echo "Board ID: $BOARD_ID"
echo "Creating cards for board..."

# Get column UUIDs from the board
echo "Fetching column UUIDs..."
BOARD_COLS=$(nak req --kind 30301 -d "$BOARD_ID" wss://relay.damus.io | jq -r '.tags[] | select(.[0] == "col") | .[1:3] | @tsv')

# Extract column UUIDs
IDEAS_UUID=$(echo "$BOARD_COLS" | grep "Ideas" | awk '{print $1}')
BACKLOG_UUID=$(echo "$BOARD_COLS" | grep "Backlog" | awk '{print $1}')
IN_PROGRESS_UUID=$(echo "$BOARD_COLS" | grep "In Progress" | awk '{print $1}')
TESTING_UUID=$(echo "$BOARD_COLS" | grep "Testing" | awk '{print $1}')
REVIEW_UUID=$(echo "$BOARD_COLS" | grep "Review" | awk '{print $1}')
DONE_UUID=$(echo "$BOARD_COLS" | grep "Done" | awk '{print $1}')

echo "Column UUIDs:"
echo "  Ideas: $IDEAS_UUID"
echo "  Backlog: $BACKLOG_UUID" 
echo "  In Progress: $IN_PROGRESS_UUID"
echo "  Testing: $TESTING_UUID"
echo "  Review: $REVIEW_UUID"
echo "  Done: $DONE_UUID"

i=0
while (( i < 5 )); do
    CARD_EVENT=$(nak event \
        --kind 30302 \
        -d "$RANDOM" \
        -t "a=30301:$CONSISTENT_PUBKEY:$BOARD_ID" \
        -t "title=$RANDOM" \
        -t "description=$RANDOM" \
        -t "alt=$RANDOM" \
        -t "priority=high" \
        -t "rank=0" \
        -t "col=$BACKLOG_UUID" \
        -t "s=Backlog" \
        -c "$RANDOM" \
        --sec "$NSEC" \
        wss://relay.damus.io -q)

    if [ -n "$CARD_EVENT" ]; then
        echo "✓ Created card $i"
        i=$(($i+1))
    fi
    sleep 3
done

echo "finished creating"