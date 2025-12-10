#!/bin/bash

# Update Kanban Cards Script
# Updates existing cards by changing their status/column

set -e

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <nsec> <npub> <card_title> <new_status>"
    echo "Example: $0 nsec1... npub1... \"Database Migration\" \"Backlog\""
    echo ""
    echo "Available statuses: Ideas, Backlog, In Progress, Testing, Review, Done, To Do"
    exit 1
fi

CARD_TITLE="$1"
export NEW_STATUS="$2"
comment="$3"
NEW_COLUMN=$(yq eval -r '.nostr.board.columns[] | select(.name == "'"$NEW_STATUS"'") | .uuid' $config)
echo $NEW_COLUMN

echo "Updating kanban card..."
echo "Card: $CARD_TITLE"
echo "New Status: $NEW_STATUS"


# Extract board information
BOARD_ID=$(yq eval -r '.nostr.board.id' $config) 
echo "Board ID: $BOARD_ID"

# Find the card with the given title AND on our specific board
echo "Searching for card: $CARD_TITLE on board: $BOARD_ID"
CARD_QUERY=$(nak req --author "$CONSISTENT_PUBKEY" -k 30302 $RELAY | jq --arg title "$CARD_TITLE" --arg board_ref "30301:$CONSISTENT_PUBKEY:$BOARD_ID" 'select((.tags[] | .[0] == "title" and .[1] == $title) and (.tags[] | .[0] == "a" and .[1] == $board_ref))')

if [ -z "$CARD_QUERY" ]; then
    echo "Error: Card '$CARD_TITLE' not found"
    exit 1
fi

# Filter out corrupted cards (with newlines in d tags) and get the most recent clean version
echo "Filtering out corrupted cards..."
CARD_JSON=$(echo "$CARD_QUERY" | jq 'select(
  ((.tags[] | select(.[0] == "d")[1]) | type == "string") and 
  (((.tags[] | select(.[0] == "d")[1]) | contains("\n")) | not) and
  (((.tags[] | select(.[0] == "d")[1]) | length) > 0) and
  (((.tags[] | select(.[0] == "d")[1]) | length) < 200)
)' | jq -s '. | sort_by(.created_at) | reverse | .[0]')

if [ -z "$CARD_JSON" ] || [ "$CARD_JSON" = "null" ]; then
    echo "Warning: No clean cards found, falling back to most recent card and generating clean identifier"
    CARD_JSON=$(echo "$CARD_QUERY" | jq -s '. | sort_by(.created_at) | reverse | .[0]')
    # Generate a clean identifier based on title - this will be our consistent identifier going forward
    CARD_IDENTIFIER="card-$(echo "$CARD_TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')-fixed-$(date +%s)"
    echo "Generated clean identifier: $CARD_IDENTIFIER"
else
    CARD_IDENTIFIER=$(echo "$CARD_JSON" | jq -r '.tags[] | select(.[0] == "d")[1]')
    echo "Using existing clean identifier: $CARD_IDENTIFIER"
fi

CARD_ID=$(echo "$CARD_JSON" | jq -r '.id')
# CARD_PRIORITY=$(echo "$CARD_JSON" | jq -r '.tags[] | select(.[0] == "priority")[1] // "medium"')
# CARD_RANK=$(echo "$CARD_JSON" | jq -r '.tags[] | select(.[0] == "rank")[1] // "0"')
# CARD_DESCRIPTION=$(echo "$CARD_JSON" | jq -r '.tags[] | select(.[0] == "description")[1] // ""')
# CARD_CONTENT=$(echo "$CARD_JSON" | jq -r '.content')
# CURRENT_STATUS=$(echo "$CARD_JSON" | jq -r '.tags[] | select(.[0] == "s")[1] // "UNMAPPED"')

CARD_PRIORITY=$(echo "$CARD_JSON" | jq -r '(.tags[] | select(.[0] == "priority"))[1] // "medium"')
CARD_RANK=$(echo "$CARD_JSON" | jq -r '(.tags[] | select(.[0] == "rank"))[1] // "0"')
CARD_DESCRIPTION=$(echo "$CARD_JSON" | jq -r '(.tags[] | select(.[0] == "description"))[1] // ""')
CARD_CONTENT=$(echo "$CARD_JSON" | jq -r '.content')
CURRENT_STATUS=$(echo "$CARD_JSON" | jq -r '(.tags[] | select(.[0] == "s"))[1] // "UNMAPPED"')

echo "Found card: $CARD_ID"
echo "Current status: $CURRENT_STATUS"
echo "Using identifier: $CARD_IDENTIFIER"
echo ""

# Debug: Show what other cards with this title exist
TOTAL_CARDS=$(echo "$CARD_QUERY" | jq -s '. | length')
echo "Debug: Found $TOTAL_CARDS cards with title '$CARD_TITLE' on this board"
if [ "$TOTAL_CARDS" -gt 1 ]; then
    echo "Debug: Other card statuses:"
    echo "$CARD_QUERY" | jq -r '.tags[] | select(.[0] == "s")[1] // "UNMAPPED"' | sort | uniq -c
    echo ""
fi

# Create updated card event (replaceable event with same identifier)
echo "Updating card to status: $NEW_STATUS"
UPDATED_EVENT=$(nak event \
    --kind 30302 \
    -d "$CARD_IDENTIFIER" \
    -t "a=30301:$CONSISTENT_PUBKEY:$BOARD_ID" \
    -t "title=$CARD_TITLE" \
    -t "description=$CARD_DESCRIPTION" \
    -t "alt=A card titled $CARD_TITLE" \
    -t "priority=$CARD_PRIORITY" \
    -t "rank=$CARD_RANK" \
    -t "s=$NEW_STATUS" \
    -t "col=$NEW_STATUS" \
    -c "$CARD_CONTENT" \
    --sec "$NSEC" )
    # $RELAY)

UPDATED_EVENT=$(nak event \
    --kind 30302 \
    -d "$CARD_IDENTIFIER" \
    -t "a=30301:$CONSISTENT_PUBKEY:$BOARD_ID" \
    -t "title=$CARD_TITLE" \
    -t "description=$CARD_DESCRIPTION" \
    -t "alt=A card titled $CARD_TITLE" \
    -t "priority=$CARD_PRIORITY" \
    -t "rank=$CARD_RANK" \
    -t "s=$NEW_STATUS" \
    -t "col=$NEW_STATUS" \
    -c "$CARD_CONTENT" \
    --sec "$NSEC" \
    $RELAY)


if [ -n "$UPDATED_EVENT" ]; then
    echo "✓ Card updated successfully!"
    echo "✓ Event ID: $(echo "$UPDATED_EVENT" | jq -r '.id')"
else
    echo "✗ Failed to update card"
    exit 1
fi

# Generate Highlighter URL for debugging
NEVENT_ENCODED=$(nak encode nevent --author "$CONSISTENT_PUBKEY" --relay $RELAY "$(echo "$UPDATED_EVENT" | jq -r '.id')")
echo ""
echo "Highlighter URL: https://highlighter.com/a/$NEVENT_ENCODED"
