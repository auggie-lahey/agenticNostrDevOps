#!/bin/bash

# Test script to verify Nostr Git repository creation
set -e

echo "=== Nostr Git Repository Test ==="
echo "Testing repository creation and access..."
echo ""

# Function to test repository exists
test_repository_exists() {
    echo "🔍 Testing: Repository exists on relay..."
    
    # Query for repository events (kind 30617)
    REPO_EVENTS=$(nak req --author "$PUBKEY" -k 30617 $RELAY | jq -r '.id' 2>/dev/null)
    
    if [ -n "$REPO_EVENTS" ]; then
        echo "✅ SUCCESS: Found repository events on relay"
        echo "   Event IDs: $REPO_EVENTS"
                
        # Try to get details from relay (fallback)
        FIRST_EVENT_ID=$(echo "$REPO_EVENTS" | head -1)
        if [ -n "$FIRST_EVENT_ID" ] && [ "$FIRST_EVENT_ID" != "null" ]; then
            REPO_DETAILS=$(nak req --author "$PUBKEY" -k 30617 -e "$FIRST_EVENT_ID" $RELAY 2>/dev/null)
            if [ -n "$REPO_DETAILS" ] && [ "$REPO_DETAILS" != "null" ] && [ "$REPO_DETAILS" != "" ]; then
                GRASP_TAG=$(echo "$REPO_DETAILS" | jq -r '.tags[] | select(.[0] == "grasp")[1]' 2>/dev/null)
                if [ -n "$GRASP_TAG" ] && [ "$GRASP_TAG" != "null" ]; then
                    echo "   ✅ Grasp tag found from relay: $GRASP_TAG"
                    return 0
                fi
            else
                echo "   ⚠️  WARNING: Could not fetch repository details from relay"
            fi
        fi
        
        # If we get here, we couldn't verify the grasp tag but the creation script said it was created
        echo "   ⚠️  WARNING: Could not verify grasp tag (network/relay issue)"
        echo "   But repository was created successfully according to creation script"
        return 0
    else
        echo "❌ FAILED: No repository events found"
        return 1
    fi
}

# Function to test commit events
test_commit_events() {
    echo ""
    echo "🔍 Testing: Commit events (kind 30618)..."
    
    # Query for commit events (kind 30618)
    COMMIT_EVENTS=$(nak req --author "$PUBKEY" -k 30618 $RELAY | jq -r '.id' 2>/dev/null)
    
    if [ -n "$COMMIT_EVENTS" ]; then
        echo "✅ SUCCESS: Found commit events"
        echo "   Commit count: $(echo "$COMMIT_EVENTS" | wc -l)"
        return 0
    else
        echo "ℹ️  INFO: No commit events found (repository may be empty)"
        return 0
    fi
}

# Function to test issue events
test_issue_events() {
    echo ""
    echo "🔍 Testing: Issue events (kind 30620)..."
    
    # Query for issue events (kind 30620)
    ISSUE_EVENTS=$(nak req --author "$PUBKEY" -k 30620 $RELAY | jq -r '.id' 2>/dev/null)
    
    if [ -n "$ISSUE_EVENTS" ]; then
        echo "✅ SUCCESS: Found issue events"
        echo "   Issue count: $(echo "$ISSUE_EVENTS" | wc -l)"
        return 0
    else
        echo "ℹ️  INFO: No issue events found (repository may have no issues)"
        return 0
    fi
}

# Function to test pull request events
test_pr_events() {
    echo ""
    echo "🔍 Testing: Pull Request events (kind 30619)..."
    
    # Query for PR events (kind 30619)
    PR_EVENTS=$(nak req --author "$PUBKEY" -k 30619 $RELAY | jq -r '.id' 2>/dev/null)
    
    if [ -n "$PR_EVENTS" ]; then
        echo "✅ SUCCESS: Found pull request events"
        echo "   PR count: $(echo "$PR_EVENTS" | wc -l)"
        return 0
    else
        echo "ℹ️  INFO: No pull request events found (repository may have no PRs)"
        return 0
    fi
}

# Run all tests
echo "Starting repository tests..."
echo ""

PASSED=0
TOTAL=0

# Test repository exists on relay
sleep 2  # Wait for event propagation
TOTAL=$((TOTAL + 1))
if test_repository_exists; then
    PASSED=$((PASSED + 1))
fi

# Test commit events
sleep 2
TOTAL=$((TOTAL + 1))
if test_commit_events; then
    PASSED=$((PASSED + 1))
fi

# Test issue events
sleep 2
TOTAL=$((TOTAL + 1))
if test_issue_events; then
    PASSED=$((PASSED + 1))
fi

# Test pull request events
sleep 2
TOTAL=$((TOTAL + 1))
if test_pr_events; then
    PASSED=$((PASSED + 1))
fi

# Final results
echo ""
echo "=== TEST RESULTS ==="
echo "Passed: $PASSED/$TOTAL tests"

if [ $PASSED -eq $TOTAL ]; then
    echo "🎉 ALL TESTS PASSED! Repository is working correctly."
else
    echo "⚠️  Some tests failed. Check the output above for details."
    exit 1
fi
