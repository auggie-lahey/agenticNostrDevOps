# Kanbanstr Nostr Board Creator

This folder contains JavaScript scripts for creating and publishing Kanban boards to Nostr using the NIP-100 specification.

## Files

### 1. `nostr_keygen.js`
- Generates a new Nostr keypair (npub/nsec)
- Outputs both hex and bech32 encoded keys

### 2. `generate_naddr.js` 
- Creates an naddr (addressable entity) for a board
- Used for referencing boards in other Nostr clients

### 3. `just_check_damus.js`
- Final working script that successfully publishes boards to Damus relay
- Creates a board with: Backlog, Todo, In Progress, Blocked, Done columns

### 4. `publish_to_damus.js`
- More comprehensive publish script with error handling
- Attempts multiple relays

## Generated Credentials

- **nsec**: `nsec1qauqw5qc52x4mkevmm7ptgns86mt4vut5l597g7cplncd2hpq4hqm5yggh`
- **npub**: `npub1kjcrpt4xv2etglzhlj3zekwuykg8n294m2y6ck4zkenp4a2w7ugq2k739s`

## Live Board

- **URL**: https://www.kanbanstr.com/#/board/b4b030aea662b2b47c57fca22cd9dc259079a8b5da89ac5aa2b6661af54ef710/my-kanban-board-final
- **Board ID**: `my-kanban-board-final`
- **Event ID**: `130df5fd97239b3a722e355e7b15cee5a08b6c8087c423b0abf2984ea07e4cf5`
- **Published to**: `wss://relay.damus.io` (board) + `wss://relay.nostr.band` (cards) ✅

## Project: CloudSync Pro
- **Total Cards**: 10 (5 in Backlog, 5 in Todo)
- **Status**: ✅ Active with simplified, actionable cards
- **Updated**: Cards simplified and distributed between Backlog and Todo columns

## Usage

```bash
# Install dependencies
npm install

# Generate new keys (optional)
npm run generate-keys

# Create and publish board
npm run create-board

# Quick update to Damus (recommended)
npm run damus-update

# Full update to Damus with more cards
npm run damus-full

# Legacy card creation (relays other than Damus)
npm run create-cards
npm run batch-cards
npm run update-cards

# Generate naddr for sharing board
npm run generate-naddr
```

## Default Relay

**Damus relay (`wss://relay.damus.io`)** is now the default for all operations.

## NIP-100 Specification

Based on the kanbanstr repository's NIP-100 specification:
- **Kind 30301**: Kanban Board Definition
- **Kind 30302**: Kanban Card events
- Boards contain column definitions with order
- Cards reference boards via `a` tag
