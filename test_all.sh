#!/bin/bash

# Test All Script
# Runs all available tests for the DevOps workflow

set -e

echo "Running All Tests..."
echo "==================="

# Test 1: Kanban Board Test
echo ""
echo "Test 1: Kanban Board"
echo "---------------------"
if [ -f "./test_kanban_board.sh" ]; then
    ./test_kanban_board.sh
    echo "Kanban board test completed"
else
    echo "Error: test_kanban_board.sh not found"
    exit 1
fi

# Test 2: Relay Query Test
echo ""
echo "Test 2: Relay Query"
echo "-------------------"
if [ -f "./test_relay_query.sh" ]; then
    ./test_relay_query.sh
    echo "Relay query test completed"
else
    echo "Error: test_relay_query.sh not found"
    exit 1
fi

echo ""
echo "All tests completed!"
echo "==================="
