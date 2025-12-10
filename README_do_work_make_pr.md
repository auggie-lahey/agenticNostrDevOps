# Do Work and Make PR Script

## Overview

The `do_work_make_pr.sh` script is a key component of the agentic DevOps workflow that performs arbitrary work and submits it as a Pull Request (PR) to the Nostr Git repository.

## Purpose

This script demonstrates the complete workflow of:
1. Performing automated work (creating/modifying files)
2. Creating a feature branch with "pr/" prefix
3. Committing changes with proper commit messages
4. Pushing the branch to Nostr Git remotes
5. Optionally updating kanban cards to reflect the PR creation

## Usage

### Basic Usage
```bash
./do_work_make_pr.sh
```

### With Kanban Card Update
```bash
./do_work_make_pr.sh "Card Title"
```

## What It Does

### Step 1: Arbitrary Work
The script creates timestamped files:
- `feature_YYYYMMDD_HHMMSS.md` - Feature documentation
- `script_YYYYMMDD_HHMMSS.sh` - Utility script
- Updates `README.md` with the latest feature information

### Step 2: Branch Creation
- Creates a new branch with prefix "pr/" (e.g., `pr/feature-20251209_205858`)
- Switches to the new branch

### Step 3: Commit Changes
- Adds all created files to Git
- Commits with a structured commit message following conventional commit format
- Includes metadata about the automation

### Step 4: Push to Remote
- Attempts to push the branch to Nostr Git servers
- Uses retry logic (up to 2 minutes) to handle propagation delays
- Provides manual retry instructions if needed

### Step 5: Optional Kanban Update
- If a card title is provided, updates the kanban card to "Review" status
- Links the PR to the kanban workflow

## File Structure

```
do_work_make_pr.sh          # Main script
config.yaml                 # Configuration file
devops663/                  # Repository directory
├── feature_*.md            # Generated feature documentation
├── script_*.sh             # Generated utility scripts
├── README.md               # Updated with latest changes
└── .git/                   # Git repository
```

## Integration

The script is integrated into the main `devops_workflow.sh` and is called after:
- Identity setup
- Kanban board creation
- Git repository initialization
- Card creation and testing

## Error Handling

The script includes comprehensive error handling:
- Checks for existing repository and configuration
- Validates Git operations
- Handles Nostr Git push failures gracefully
- Provides clear error messages and retry instructions

## Output

The script provides detailed output including:
- Step-by-step progress indicators
- File creation confirmations
- Git operation results
- PR summary with URLs
- Next steps for review and merging

## Example Output

```
=== DO WORK AND MAKE PR ===
Repository: devops663
Repository directory: devops663

Step 1: Performing arbitrary work...
Creating feature file: feature_20251209_205858.md
✓ Arbitrary work completed
✓ Created: feature_20251209_205858.md
✓ Created: script_20251209_205858.sh
✓ Updated: README.md

Step 2: Creating PR branch: pr/feature-20251209_205858
Switched to a new branch 'pr/feature-20251209_205858'

Step 3: Committing changes...
✓ Changes committed successfully

Step 4: Pushing PR branch to remote...
✓ PR branch pushed successfully

=== PR SUMMARY ===
✓ Feature branch: pr/feature-20251209_205858
✓ Repository: devops663
✓ Files created:
  - feature_20251209_205858.md
  - script_20251209_205858.sh
  - README.md (updated)

=== ACCESS URLS ===
Git Workshop: https://gitworkshop.dev/...
Nostr Repository: https://highlighter.com/a/...

=== NEXT STEPS ===
1. Review the changes in the PR branch: pr/feature-20251209_205858
2. Test the implementation
3. Merge the PR when ready
4. Update kanban card to 'Review' or 'Done'

✓ Work and PR creation completed successfully!
```

## Testing

Use the provided test script to verify functionality:
```bash
./test_do_work_make_pr.sh
```

## Dependencies

- `yq` - YAML processor
- `nak` - Nostr command-line tool
- `git` - Version control
- `jq` - JSON processor
- Valid Nostr identity and repository in `config.yaml`

## Customization

The script can be customized by modifying:
- File creation logic in Step 1
- Branch naming convention
- Commit message format
- Retry logic timing
- Integration with other workflow components
