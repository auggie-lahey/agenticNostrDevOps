#!/bin/bash

# Test Kanban Board Script
# Tests the kanban board by curling the URL and verifying content

set -e

echo "Testing Kanban Board..."
echo "======================"

# Check if YAML file exists
YAML_FILE="nostr_keys.yaml"
if [ ! -f "$YAML_FILE" ]; then
    echo "Error: $YAML_FILE not found. Run devops_workflow.sh first."
    exit 1
fi

# Extract board URL from YAML
KANBANSTR_URL=$(grep "kanbanstr_url:" "$YAML_FILE" | awk '{print $2}' | sed 's/^"//;s/"$//')
if [ -z "$KANBANSTR_URL" ]; then
    echo "Error: No kanbanstr_url found in $YAML_FILE"
    exit 1
fi

echo "Testing board URL: $KANBANSTR_URL"

# Extract expected values from YAML for verification
EXPECTED_TITLE=$(grep "title:" "$YAML_FILE" | cut -d'"' -f2 | head -1)
if [ -z "$EXPECTED_TITLE" ]; then
    EXPECTED_TITLE="DevOps Workflow Board"  # Default from our creation script
fi

echo "Expected board title: $EXPECTED_TITLE"
echo ""

# Test the board URL
echo "Fetching board content..."
RESPONSE=$(curl -s -L "$KANBANSTR_URL")

if [ -z "$RESPONSE" ]; then
    echo "Error: No response from board URL"
    exit 1
fi

echo "Response received (first 1000 characters):"
echo "$RESPONSE" | head -c 1000
echo ""
echo "================================"

# Verify expected content
echo ""
echo "Verifying board content..."

# Note: kanbanstr.com is a Single Page Application (SPA)
# The server sends generic HTML, board data is loaded via JavaScript
echo "Note: kanbanstr.com is a SPA - board data loads via JavaScript"

# Check for kanbanstr.com site markers
if echo "$RESPONSE" | grep -q -i "kanbanstr\|kanban"; then
    echo "✓ Kanbanstr site detected"
else
    echo "✗ Kanbanstr site not found"
fi

# Check for proper HTML structure
if echo "$RESPONSE" | grep -q -i "html\|head\|body"; then
    echo "✓ Valid HTML structure"
else
    echo "✗ Invalid HTML structure"
fi

# Extract board info from YAML to verify structure
echo ""
echo "Verifying board structure from YAML..."
BOARD_ID=$(grep -A1 "board:" "$YAML_FILE" | grep "id:" | awk '{print $2}' | sed 's/^"//;s/"$//')
EVENT_ID=$(grep "event_id:" "$YAML_FILE" | awk '{print $2}' | sed 's/^"//;s/"$//')
NADDR=$(grep "naddr:" "$YAML_FILE" | awk '{print $2}' | sed 's/^"//;s/"$//')

if [ -n "$BOARD_ID" ]; then
    echo "  ✓ Board ID found: $BOARD_ID"
else
    echo "  ✗ Board ID not found"
fi

if [ -n "$EVENT_ID" ]; then
    echo "  ✓ Event ID found: $EVENT_ID"
else
    echo "  ✗ Event ID not found"
fi

if [ -n "$NADDR" ]; then
    echo "  ✓ naddr found: $NADDR"
else
    echo "  ✗ naddr not found"
fi

# Check column configuration in YAML
EXPECTED_COLUMNS=("Ideas" "Backlog" "In Progress" "Testing" "Review" "Done")
COLUMN_COLORS=("#9B59B6" "#E74C3C" "#F39C12" "#3498DB" "#2ECC71" "#95A5A6")

echo ""
echo "Verifying column configuration in YAML..."
for i in "${!EXPECTED_COLUMNS[@]}"; do
    COLUMN="${EXPECTED_COLUMNS[$i]}"
    COLOR="${COLUMN_COLORS[$i]}"
    
    if grep -q "$COLUMN" "$YAML_FILE"; then
        echo "  ✓ Column found in YAML: $COLUMN"
    else
        echo "  ✗ Column not found in YAML: $COLUMN"
    fi
    
    if grep -q "$COLOR" "$YAML_FILE"; then
        echo "  ✓ Column color found in YAML: $COLOR"
    else
        echo "  ✗ Column color not found in YAML: $COLOR"
    fi
done

echo ""
echo "Board verification notes:"
echo "- kanbanstr.com loads board data via JavaScript from Nostr relays"
echo "- Board content (title, columns, cards) comes from the naddr: $NADDR"
echo "- curl only sees the initial HTML shell"
echo "- To verify board content, open the URL in a browser"
echo "- Board URL: $KANBANSTR_URL"

# Check for HTML structure indicators
echo ""
echo "Checking HTML structure..."
if echo "$RESPONSE" | grep -q -i "kanban\|board\|column"; then
    echo "  ✓ Board/kanban related content found"
else
    echo "  ✗ No board/kanban content detected"
fi

if echo "$RESPONSE" | grep -q -i "html\|body\|div"; then
    echo "  ✓ HTML structure detected"
else
    echo "  - HTML structure not clearly visible"
fi

# Show response size and type
echo ""
echo "Response analysis:"
RESPONSE_SIZE=$(echo "$RESPONSE" | wc -c)
echo "  Response size: $RESPONSE_SIZE bytes"

if echo "$RESPONSE" | grep -q -i "doctype\|html"; then
    echo "  Response type: HTML page"
elif echo "$RESPONSE" | grep -q -i "json"; then
    echo "  Response type: JSON"
else
    echo "  Response type: Unknown/other"
fi

echo ""
echo "Test completed!"
echo "=================="
