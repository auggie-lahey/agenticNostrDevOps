#!/bin/bash

# Generic Update Card Script
# Updates any field of a kanban card with a new value

set -e

# Check arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <card_title> <field> <new_value> [comment]"
    echo "Example: $0 \"Database Migration\" \"description\" \"Updated description\""
    echo "Example: $0 \"API Integration\" \"status\" \"Review\" \"Moving to review\""
    echo ""
    echo "Available fields: title, description, status, priority, rank, content"
    exit 1
fi

CARD_TITLE="$1"
FIELD="$2"
NEW_VALUE="$3"
COMMENT="$4"

echo "Updating kanban card field..."
echo "Card: $CARD_TITLE"
echo "Field: $FIELD"
echo "New Value: $NEW_VALUE"

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

# Filter out corrupted cards and get the most recent clean version
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

# Extract existing card data
CARD_TITLE_EXISTING=$(echo "$CARD_JSON" | jq -r '(.tags[] | select(.[0] == "title"))[1] // "'"$CARD_TITLE"'"')
CARD_DESCRIPTION=$(echo "$CARD_JSON" | jq -r '(.tags[] | select(.[0] == "description"))[1] // ""')
CARD_PRIORITY=$(echo "$CARD_JSON" | jq -r '(.tags[] | select(.[0] == "priority"))[1] // "medium"')
CARD_RANK=$(echo "$CARD_JSON" | jq -r '(.tags[] | select(.[0] == "rank"))[1] // "0"')
CARD_STATUS=$(echo "$CARD_JSON" | jq -r '(.tags[] | select(.[0] == "s"))[1] // "Ideas"')
CARD_CONTENT=$(echo "$CARD_JSON" | jq -r '.content')

# Update the specific field
case "$FIELD" in
    "title")
        CARD_TITLE_EXISTING="$NEW_VALUE"
        ;;
    "description")
        CARD_DESCRIPTION="$NEW_VALUE"
        ;;
    "status"|"s")
        CARD_STATUS="$NEW_VALUE"
        ;;
    "priority")
        CARD_PRIORITY="$NEW_VALUE"
        ;;
    "rank")
        CARD_RANK="$NEW_VALUE"
        ;;
    "content")
        CARD_CONTENT="$NEW_VALUE"
        ;;
    *)
        echo "Error: Unknown field '$FIELD'"
        echo "Available fields: title, description, status, priority, rank, content"
        exit 1
        ;;
esac

echo "Found card: $CARD_ID"
echo "Updating $FIELD to: $NEW_VALUE"
echo "Using identifier: $CARD_IDENTIFIER"
echo ""

# Get column UUID for status updates
NEW_COLUMN=$(yq eval -r '.nostr.board.columns[] | select(.name == "'"$CARD_STATUS"'") | .uuid' $config 2>/dev/null || echo "")

# Create updated card event (replaceable event with same identifier)
echo "Creating updated card event..."
UPDATED_EVENT=$(nak event \
    --kind 30302 \
    -d "$CARD_IDENTIFIER" \
    -t "a=30301:$CONSISTENT_PUBKEY:$BOARD_ID" \
    -t "title=$CARD_TITLE_EXISTING" \
    -t "description=$CARD_DESCRIPTION" \
    -t "alt=A card titled $CARD_TITLE_EXISTING" \
    -t "priority=$CARD_PRIORITY" \
    -t "rank=$CARD_RANK" \
    -t "s=$CARD_STATUS" \
    $([ -n "$NEW_COLUMN" ] && echo "-t \"col=$NEW_COLUMN\"") \
    -c "$CARD_CONTENT" \
    --sec "$NSEC" \
    $RELAY)

if [ -n "$UPDATED_EVENT" ]; then
    echo "✓ Card field updated successfully!"
    echo "✓ Event ID: $(echo "$UPDATED_EVENT" | jq -r '.id')"
else
    echo "✗ Failed to update card field"
    exit 1
fi

# Generate Highlighter URL for debugging
NEVENT_ENCODED=$(nak encode nevent --author "$CONSISTENT_PUBKEY" --relay $RELAY "$(echo "$UPDATED_EVENT" | jq -r '.id')")
echo ""
echo "Highlighter URL: https://highlighter.com/a/$NEVENT_ENCODED"
echo "✓ Card field update completed!"
