#!/bin/bash

# Test Relay Query Script
# Queries Nostr relays to verify the board event was successfully published

set -e

# Use only damus relay
RELAYS=(
    "$RELAY"
)
# Extract board information from YAML
BOARD_ID=$(yq e -r ".nostr.board.id" "$config")
EVENT_ID=$(yq e -r ".nostr.board.event_id" "$config")
NPUB=$(yq e -r ".nostr.identity.public_key.npub" "$config")

# Extract pubkey from npub (this will match the actual event author)
QUERY_PUBKEY=$PUBKEY
# Test 1: Query by event ID
echo "Test 1: Querying by Event ID"
EVENT_FOUND=false
for RELAY in "${RELAYS[@]}"; do
    EVENT_QUERY=$(nak req --id "$EVENT_ID" "$RELAY" 2>/dev/null | timeout 10 cat 2>/dev/null || echo "")
    if [ -n "$EVENT_QUERY" ]; then
        EVENT_FOUND=true
        echo "✓ Event ID query: SUCCESS"
        break
    fi
done

if [ "$EVENT_FOUND" = false ]; then
    echo "✗ Event ID query: FAILED"
    exit
fi

# Test 2: Query by author and kind (30301)
echo "Test 2: Querying by Author and Kind"
BOARD_EVENT_FOUND=false
for RELAY in "${RELAYS[@]}"; do
    AUTHOR_QUERY=$(nak req --author "$QUERY_PUBKEY" -k 30301 "$RELAY" )
    if [ -n "$AUTHOR_QUERY" ]; then
        if echo "$AUTHOR_QUERY" | grep -q "$BOARD_ID"; then
            BOARD_EVENT_FOUND=true
            echo "✓ Author/Kind query: SUCCESS"
            break
        fi
    fi
done

if [ "$BOARD_EVENT_FOUND" = false ]; then
    echo "✗ Author/Kind query: FAILED"
    exit
fi

# Test 3: Query by naddr parameterized replaceable event
echo "Test 3: Querying by naddr (NIP-33)"
NADDR=$(yq e -r ".nostr.board.naddr" "$config")
NADDR_EVENT_FOUND=false
for RELAY in "${RELAYS[@]}"; do
    NADDR_DECODE=$(nak decode "$NADDR" 2>/dev/null || echo "")
    if [ -n "$NADDR_DECODE" ]; then
        NADDR_QUERY=$(nak req --author "$QUERY_PUBKEY" -k 30301 -d "$BOARD_ID" "$RELAY" 2>/dev/null | timeout 10 cat 2>/dev/null || echo "")
        if [ -n "$NADDR_QUERY" ]; then
            NADDR_EVENT_FOUND=true
            echo "✓ naddr query: SUCCESS"
            break
        fi
    fi
done

if [ "$NADDR_EVENT_FOUND" = false ]; then
    echo "✗ naddr query: FAILED"
fi
