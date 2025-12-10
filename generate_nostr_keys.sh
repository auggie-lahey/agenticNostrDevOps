#!/bin/bash

echo "generating keys"
# Generate a new secret key (in hex format) once and store it
SECRET_KEY_HEX=$(nak key generate)

if [ -z "$SECRET_KEY_HEX" ]; then
    echo "Error: Failed to generate secret key"
    exit 1
fi

# Get the public key (in hex format) from the same secret key
PUBKEY_HEX=$(nak key public "$SECRET_KEY_HEX")
if [ -z "$PUBKEY_HEX" ]; then
    echo "Error: Failed to get public key from secret key"
    exit 1
fi

# Encode the same secret key to nsec format
NSEC=$(nak encode nsec "$SECRET_KEY_HEX")
if [ -z "$NSEC" ]; then
    echo "Error: Failed to encode nsec"
    exit 1
fi

# Encode the same public key to npub format
NPUB=$(nak encode npub "$PUBKEY_HEX")
if [ -z "$NPUB" ]; then
    echo "Error: Failed to encode npub"
    exit 1
fi

# Only output the keys
echo "$NSEC"
echo "$NPUB"

# Save to YAML file
cat > $config << EOF
nostr:
  identity:
    private_key:
      nsec: "$NSEC"
      generated_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    public_key:
      npub: "$NPUB"
      generated_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
EOF
