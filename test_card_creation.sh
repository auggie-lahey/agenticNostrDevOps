#!/bin/bash

# Test Card Creation Script
# Tests that kanban cards were successfully created and are accessible

set -e

echo "Testing card creation..."

# Extract board information
BOARD_ID=$(yq e -r '.nostr.board.id' "$config")
EVENT_ID=$(yq e -r '.nostr.board.event_id' "$config")

# Use only damus relay
RELAYS=("wss://relay.damus.io")

# Test 1: Query board event to verify board exists
echo "Test 1: Verifying board exists"
BOARD_FOUND=false
for RELAY in "${RELAYS[@]}"; do
    BOARD_QUERY=$(nak req --id "$EVENT_ID" "$RELAY" 2>/dev/null | timeout 10 cat 2>/dev/null || echo "")
    if [ -n "$BOARD_QUERY" ]; then
        BOARD_FOUND=true
        break
    fi
done

if [ "$BOARD_FOUND" = true ]; then
    echo "✓ Board query: SUCCESS"
else
    echo "✗ Board query: FAILED - Board not found"
    exit 1
fi

# Test 2: Query for kanban cards (kind 30302) linked to this board
echo "Test 2: Querying for kanban cards"
CARDS_FOUND=false
CARD_COUNT=0
for RELAY in "${RELAYS[@]}"; do
    CARDS_QUERY=$(nak req --author "$QUERY_PUBKEY" -k 30302 "$RELAY" -q)
    if [ -n "$CARDS_QUERY" ]; then
        BOARD_CARDS=$(echo "$CARDS_QUERY" | grep -o "$BOARD_ID" | wc -l)
        if [ "$BOARD_CARDS" -gt 0 ]; then
            CARD_COUNT=$((CARD_COUNT + BOARD_CARDS))
            CARDS_FOUND=true
        fi
    fi
done

if [ "$CARDS_FOUND" = true ]; then
    echo "✓ Cards query: SUCCESS (Found $CARD_COUNT cards)"
else
    echo "✗ Cards query: FAILED - No cards found for board"
    exit 1
fi

# Test 2.5: Verify cards are using correct 'a' tag format
echo "Test 2.5: Verifying card board linking format"
A_TAG_VALID=false
# Check if cards have proper 'a' tags linking to board
for RELAY in "${RELAYS[@]}"; do
    CARDS_QUERY=$(nak req --author "$QUERY_PUBKEY" -k 30302 "$RELAY" -q)
    if [ -n "$CARDS_QUERY" ]; then
        A_CARDS=$(echo "$CARDS_QUERY" | jq -r '.tags[] | select(.[0] == "a") | .[1]' | grep -c "30301:$QUERY_PUBKEY:$BOARD_ID" || echo "0")
        if [ "$A_CARDS" -gt 0 ]; then
            A_TAG_VALID=true
            echo "✓ Found $A_CARDS cards with proper 'a' tag board linking"
        fi
    fi
done

if [ "$A_TAG_VALID" = true ]; then
    echo "✓ Card board linking: SUCCESS"
else
    echo "✗ Card board linking: FAILED - Cards not using proper 'a' tag format"
    exit 1
fi

# Test 3: Verify cards have required content
echo "Test 3: Verifying card content"
CONTENT_VALID=false

for RELAY in "${RELAYS[@]}"; do
    CARDS_QUERY=$(nak req --author "$QUERY_PUBKEY" -k 30302 "$RELAY" 2>/dev/null | timeout 10 cat 2>/dev/null || echo "")
    if [ -n "$CARDS_QUERY" ]; then
        # Check if cards have title and description tags
        if echo "$CARDS_QUERY" | grep -q '"title"' && echo "$CARDS_QUERY" | grep -q '"description"'; then
            CONTENT_VALID=true
            break
        fi
    fi
done

if [ "$CONTENT_VALID" = true ]; then
    echo "✓ Card content: SUCCESS (Cards have titles and descriptions)"
else
    echo "✗ Card content: FAILED - Cards missing required content"
    exit 1
fi

# # Test 4: Check YAML file for cards_created field
# echo "Test 4: Verifying YAML card count"
# YAML_CARDS_CREATED=0
# if grep -q "cards_created:" "$config"; then
#     YAML_CARDS_CREATED=$(grep "cards_created:" "$config" | awk '{print $2}')
#     echo "✓ YAML card count: SUCCESS (Recorded: $YAML_CARDS_CREATED)"
# else
#     echo "⚠ YAML card count: WARNING - No cards_created field in YAML"
# fi

# Summary
# echo ""
# echo "Card Creation Test Results:"
# if [ "$BOARD_FOUND" = true ] && [ "$CARDS_FOUND" = true ] && [ "$CONTENT_VALID" = true ]; then
#     echo "✓ SUCCESS: All card creation tests passed"
#     echo "✓ Board: $BOARD_ID"
#     echo "✓ Cards found: $CARD_COUNT"
#     if [ "$YAML_CARDS_CREATED" -gt 0 ]; then
#         echo "✓ YAML recorded: $YAML_CARDS_CREATED"
#     fi
# else
#     echo "✗ FAILURE: Some card creation tests failed"
#     exit 1
# fi
