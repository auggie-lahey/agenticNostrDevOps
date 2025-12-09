#!/bin/bash

# Test repository section detection in workflow
echo "Testing repository section detection..."

if [ -f "nostr_keys.yaml" ] && grep -q "  repository:" nostr_keys.yaml; then
    echo "✓ Repository section found in YAML"
    REPO_NADDR=$(grep "naddr:" nostr_keys.yaml | grep -v "kanbanstr" | head -1 | awk '{print $2}' | tr -d '"')
    REPO_URL=$(grep "gitworkshop_url:" nostr_keys.yaml | awk '{print $2}' | tr -d '"')
    echo "Repository naddr: $REPO_NADDR"
    echo "Git workshop URL: $REPO_URL"
else
    echo "❌ Repository section not found in YAML"
fi
