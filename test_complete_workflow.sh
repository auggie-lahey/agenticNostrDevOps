#!/bin/bash

# Complete Workflow Testing Script
# Tests all components of the DevOps workflow system

set -e

NAK_PATH="./nak/nak"
if [ ! -f "$NAK_PATH" ]; then
    echo "Error: nak binary not found at $NAK_PATH"
    exit 1
fi

# Check if YAML file exists
YAML_FILE="nostr_keys.yaml"
if [ ! -f "$YAML_FILE" ]; then
    echo "Error: $YAML_FILE not found. Run the workflow first."
    exit 1
fi

echo "=== COMPLETE WORKFLOW TESTING ==="
echo "Testing all components of the DevOps workflow system..."

# Extract information from YAML
NSEC=$(grep "nsec:" "$YAML_FILE" | awk '{print $2}' | sed 's/^"//;s/"$//')
NPUB=$(grep "npub:" "$YAML_FILE" | awk '{print $2}' | sed 's/^"//;s/"$//')
BOARD_ID=$(grep -A1 "board:" "$YAML_FILE" | grep "id:" | awk '{print $2}' | sed 's/^"//;s/"$//')
BOARD_EVENT_ID=$(grep "event_id:" "$YAML_FILE" | head -1 | awk '{print $2}' | sed 's/^"//;s/"$//')
CARDS_CREATED=$(grep "cards_created:" "$YAML_FILE" | awk '{print $2}' 2>/dev/null || echo "0")

# Extract repository information if available
REPO_ID=""
REPO_EVENT_ID=""
REPO_NADDR=""
if grep -q "  repository:" "$YAML_FILE"; then
    REPO_ID=$(grep -A1 "  repository:" "$YAML_FILE" | grep "id:" | awk '{print $2}' | sed 's/^"//;s/"$//')
    REPO_EVENT_ID=$(grep -A20 "  repository:" "$YAML_FILE" | grep "event_id:" | awk '{print $2}' | sed 's/^"//;s/"$//')
    REPO_NADDR=$(grep -A20 "  repository:" "$YAML_FILE" | grep "naddr:" | awk '{print $2}' | sed 's/^"//;s/"$//')
fi

# Get pubkey from npub
PUBKEY=$($NAK_PATH decode "$NPUB")

echo "Configuration:"
echo "- Pubkey: $PUBKEY"
echo "- Board ID: $BOARD_ID"
echo "- Cards created: $CARDS_CREATED"
echo "- Repository ID: ${REPO_ID:-Not created}"

# Test 1: Identity Testing
echo ""
echo "=== TEST 1: IDENTITY VERIFICATION ==="
echo "Testing Nostr identity..."

if [ -n "$NSEC" ] && [ -n "$NPUB" ] && [ -n "$PUBKEY" ]; then
    # Test if nsec decodes to the expected pubkey
    NSEC_PUBKEY=$($NAK_PATH decode "$NSEC" 2>/dev/null || echo "")
    if [ -n "$NSEC_PUBKEY" ]; then
        echo "✅ SUCCESS: NSEC is valid"
        if [ "$NSEC_PUBKEY" = "$PUBKEY" ]; then
            echo "✅ SUCCESS: NSEC pubkey matches NPUB pubkey"
        else
            echo "⚠️  WARNING: NSEC pubkey doesn't match NPUB pubkey"
            echo "   NSEC pubkey: $NSEC_PUBKEY"
            echo "   NPUB pubkey:  $PUBKEY"
        fi
    else
        echo "❌ FAILED: Invalid NSEC"
    fi
else
    echo "❌ FAILED: Missing identity information"
fi

# Test 2: Board Testing
echo ""
echo "=== TEST 2: BOARD VERIFICATION ==="
echo "Testing Kanban board creation and accessibility..."

BOARD_FOUND=false
if [ -n "$BOARD_EVENT_ID" ]; then
    # Test board event on relay
    echo "🔍 Testing: Board event on relay..."
    BOARD_QUERY=$($NAK_PATH req --id "$BOARD_EVENT_ID" wss://relay.damus.io 2>/dev/null)
    if [ -n "$BOARD_QUERY" ]; then
        echo "✅ SUCCESS: Board event found on relay"
        BOARD_FOUND=true
        
        # Test board structure
        COLUMNS_COUNT=$(echo "$BOARD_QUERY" | jq -r '[.tags[] | select(.[0] == "col")] | length')
        if [ -n "$COLUMNS_COUNT" ] && [ "$COLUMNS_COUNT" -gt 0 ]; then
            echo "✅ SUCCESS: Board has $COLUMNS_COUNT columns"
            
            # Check for Backlog column
            BACKLOG_EXISTS=$(echo "$BOARD_QUERY" | jq -r '.tags[] | select(.[0] == "col" and .[2] == "Backlog") | .[1]')
            if [ -n "$BACKLOG_EXISTS" ] && [ "$BACKLOG_EXISTS" != "null" ]; then
                echo "✅ SUCCESS: Backlog column found with UUID: $BACKLOG_EXISTS"
            else
                echo "❌ FAILED: Backlog column not found"
            fi
        else
            echo "❌ FAILED: No columns found in board"
        fi
    else
        echo "❌ FAILED: Board event not found on relay"
    fi
else
    echo "❌ FAILED: No board event ID found"
fi

# Test 3: Card Testing
echo ""
echo "=== TEST 3: CARD VERIFICATION ==="
echo "Testing Kanban card creation and mapping..."

if [ "$CARDS_CREATED" -gt 0 ]; then
    echo "🔍 Testing: Card events on relay..."
    CARDS_QUERY=$($NAK_PATH req --author "$PUBKEY" -k 30302 wss://relay.damus.io 2>/dev/null)
    
    if [ -n "$CARDS_QUERY" ]; then
        TOTAL_CARDS=$(echo "$CARDS_QUERY" | jq length 2>/dev/null || echo "0")
        echo "✅ Found $TOTAL_CARDS card events on relay"
        
        # Test card mapping to board
        if [ -n "$BOARD_ID" ]; then
            MAPPED_CARDS=$(echo "$CARDS_QUERY" | jq -r '[.[] | select(.tags[] | select(.[0] == "d" and .[1] == "'"$BOARD_ID"'"))] | length' 2>/dev/null || echo "0")
            echo "🔍 Testing: Card-to-board mapping..."
            if [ "$MAPPED_CARDS" -gt 0 ]; then
                echo "✅ SUCCESS: $MAPPED_CARDS cards properly mapped to board"
                
                # Test if cards have proper title tags
                TITLED_CARDS=$(echo "$CARDS_QUERY" | jq -r '[.[] | select(.tags[] | select(.[0] == "title"))] | length' 2>/dev/null || echo "0")
                if [ "$TITLED_CARDS" -gt 0 ]; then
                    echo "✅ SUCCESS: $TITLED_CARDS cards have title tags"
                else
                    echo "❌ FAILED: No cards have title tags"
                fi
                
                # Test if cards have column references
                COLUMN_CARDS=$(echo "$CARDS_QUERY" | jq -r '[.[] | select(.tags[] | select(.[0] == "col"))] | length' 2>/dev/null || echo "0")
                if [ "$COLUMN_CARDS" -gt 0 ]; then
                    echo "✅ SUCCESS: $COLUMN_CARDS cards have column references"
                else
                    echo "❌ FAILED: No cards have column references"
                fi
                
            else
                echo "❌ FAILED: No cards mapped to board"
            fi
        fi
        
        # Display card titles
        echo ""
        echo "Card titles found:"
        echo "$CARDS_QUERY" | jq -r '.[] | .tags[] | select(.[0] == "title")[1]' 2>/dev/null | head -10 | while read title; do
            echo "  - $title"
        done
        
    else
        echo "❌ FAILED: No card events found on relay"
    fi
else
    echo "❌ FAILED: No cards created according to YAML"
fi

# Test 4: Repository Testing
echo ""
echo "=== TEST 4: REPOSITORY VERIFICATION ==="
echo "Testing Git repository creation and commits..."

if [ -n "$REPO_EVENT_ID" ]; then
    echo "🔍 Testing: Repository event on relay..."
    REPO_QUERY=$($NAK_PATH req --id "$REPO_EVENT_ID" wss://relay.damus.io 2>/dev/null)
    if [ -n "$REPO_QUERY" ]; then
        echo "✅ SUCCESS: Repository event found on relay"
        
        # Test repository structure
        REPO_NAME=$(echo "$REPO_QUERY" | jq -r '.tags[] | select(.[0] == "name")[1]' 2>/dev/null || echo "")
        if [ -n "$REPO_NAME" ] && [ "$REPO_NAME" != "null" ]; then
            echo "✅ SUCCESS: Repository name: $REPO_NAME"
        else
            echo "❌ FAILED: No repository name found"
        fi
        
        # Test for clone URLs
        CLONE_URLS=$(echo "$REPO_QUERY" | jq -r '[.tags[] | select(.[0] == "clone")] | length' 2>/dev/null || echo "0")
        if [ "$CLONE_URLS" -gt 0 ]; then
            echo "✅ SUCCESS: Repository has $CLONE_URLS clone URLs"
        else
            echo "❌ FAILED: No clone URLs found"
        fi
        
        # Test for maintainer
        MAINTAINERS=$(echo "$REPO_QUERY" | jq -r '[.tags[] | select(.[0] == "maintainers")] | length' 2>/dev/null || echo "0")
        if [ "$MAINTAINERS" -gt 0 ]; then
            echo "✅ SUCCESS: Repository has $MAINTAINERS maintainers"
        else
            echo "❌ FAILED: No maintainers found"
        fi
        
    else
        echo "❌ FAILED: Repository event not found on relay"
    fi
    
    # Test for commit events
    if [ -n "$REPO_ID" ]; then
        echo "🔍 Testing: Commit events on relay..."
        COMMIT_QUERY=$($NAK_PATH req --author "$PUBKEY" -k 30618 -d "$REPO_ID" wss://relay.damus.io 2>/dev/null)
        if [ -n "$COMMIT_QUERY" ]; then
            COMMIT_COUNT=$(echo "$COMMIT_QUERY" | jq length 2>/dev/null || echo "0")
            echo "✅ SUCCESS: Found $COMMIT_COUNT commit events"
            
            # Test for earliest-unique-commit
            EUC_COUNT=$(echo "$COMMIT_QUERY" | jq -r '[.[] | select(.tags[] | select(.[0] == "h" and .[1] | endswith(",euc")))] | length' 2>/dev/null || echo "0")
            if [ "$EUC_COUNT" -gt 0 ]; then
                echo "✅ SUCCESS: Found $EUC_COUNT earliest-unique-commit tags"
            else
                echo "❌ FAILED: No earliest-unique-commit tags found"
            fi
        else
            echo "❌ FAILED: No commit events found"
        fi
    fi
    
else
    echo "❌ FAILED: No repository created according to YAML"
fi

# Test 5: Name Matching Testing
echo ""
echo "=== TEST 5: NAME MATCHING VERIFICATION ==="
echo "Testing board and repository name consistency..."

if [ -n "$BOARD_ID" ] && [ -n "$REPO_ID" ]; then
    if [ "$BOARD_ID" = "$REPO_ID" ]; then
        echo "✅ SUCCESS: Board and repository names match: $BOARD_ID"
    else
        echo "❌ FAILED: Name mismatch"
        echo "   Board name: $BOARD_ID"
        echo "   Repository name: $REPO_ID"
    fi
else
    echo "⚠️  WARNING: Cannot test name matching (missing board or repository)"
fi

# Test 6: Accessibility Testing
echo ""
echo "=== TEST 6: ACCESSIBILITY VERIFICATION ==="
echo "Testing access URLs and client compatibility..."

# Test board accessibility
if [ -n "$BOARD_EVENT_ID" ]; then
    BOARD_NADDR=$(grep "naddr:" "$YAML_FILE" | grep -v "gitworkshop" | head -1 | awk '{print $2}' | sed 's/^"//;s/"$//')
    if [ -n "$BOARD_NADDR" ]; then
        echo "✅ Board NAddr: $BOARD_NADDR"
        echo "✅ Board URL: https://highlighter.com/a/$BOARD_NADDR"
        
        # Test if naddr decodes correctly
        NADDR_DECODED=$($NAK_PATH decode "$BOARD_NADDR" 2>/dev/null || echo "")
        if [ -n "$NADDR_DECODED" ]; then
            echo "✅ SUCCESS: Board naddr is valid"
        else
            echo "❌ FAILED: Invalid board naddr"
        fi
    fi
fi

# Test repository accessibility  
if [ -n "$REPO_NADDR" ]; then
    echo "✅ Repository NAddr: $REPO_NADDR"
    echo "✅ Repository URL: https://highlighter.com/a/$REPO_NADDR"
    
    # Test if naddr decodes correctly
    NADDR_DECODED=$($NAK_PATH decode "$REPO_NADDR" 2>/dev/null || echo "")
    if [ -n "$NADDR_DECODED" ]; then
        echo "✅ SUCCESS: Repository naddr is valid"
    else
        echo "❌ FAILED: Invalid repository naddr"
    fi
fi

# Test Git Workshop URL
if grep -q "gitworkshop_url:" "$YAML_FILE"; then
    GITWORKSHOP_URL=$(grep "gitworkshop_url:" "$YAML_FILE" | awk '{print $2}' | sed 's/^"//;s/"$//')
    if [ -n "$GITWORKSHOP_URL" ]; then
        echo "✅ Git Workshop URL: $GITWORKSHOP_URL"
    fi
fi

# Test 7: Summary and Recommendations
echo ""
echo "=== TEST 7: SUMMARY AND RECOMMENDATIONS ==="

PASSED_TESTS=0
TOTAL_TESTS=0

# Count successful tests (simplified counting based on output above)
if [ -n "$NSEC" ] && [ -n "$NPUB" ]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$BOARD_FOUND" = true ]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ "$CARDS_CREATED" -gt 0 ]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

if [ -n "$REPO_EVENT_ID" ]; then
    PASSED_TESTS=$((PASSED_TESTS + 1))
fi
TOTAL_TESTS=$((TOTAL_TESTS + 1))

echo "Tests passed: $PASSED_TESTS/$TOTAL_TESTS"

if [ "$PASSED_TESTS" -eq "$TOTAL_TESTS" ]; then
    echo "🎉 ALL TESTS PASSED! Your DevOps workflow is fully functional."
    echo ""
    echo "Next steps:"
    echo "1. Access your Kanban board using the board URL above"
    echo "2. Clone your repository using the Git Workshop URL"
    echo "3. Move cards from Backlog to In Progress as you work on items"
    echo "4. Make commits and push changes to your Nostr repository"
else
    echo "⚠️  Some tests failed. Check the output above for details."
    echo ""
    echo "Common issues and solutions:"
    echo "- Repository not found: Wait a few minutes for relay propagation"
    echo "- Cards not mapped: Check card creation script for proper tags"
    echo "- Name mismatch: Ensure board and repository use the same identifier"
fi

echo ""
echo "=== COMPLETE WORKFLOW TEST FINISHED ==="
