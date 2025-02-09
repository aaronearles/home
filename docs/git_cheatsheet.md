# Git Command Line Cheatsheet

## Setup & Configuration
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
git config --list                    # Show configuration
```

## Basic Commands
```bash
git init                    # Initialize repository
git clone <url>             # Clone repository
git status                  # Check status
git add <file>              # Stage file
git add .                   # Stage all files
git commit -m "message"     # Commit with message
git commit -am "message"    # Stage tracked files and commit
```

## Branching & Merging
```bash
git branch                  # List branches
git branch <name>           # Create branch
git branch -d <name>        # Delete branch
git checkout <branch>       # Switch branch
git checkout -b <name>      # Create and switch branch
git merge <branch>          # Merge branch into current
git rebase <branch>         # Rebase current on branch
```

## Remote Operations
```bash
git remote -v                # List remotes
git remote add <name> <url>  # Add remote
git push <remote> <branch>   # Push to remote
git pull <remote> <branch>   # Pull from remote
git fetch <remote>           # Fetch from remote
```

## History & Differences
```bash
git log                     # View commit history
git log --oneline           # Compact history view
git diff                    # Show unstaged changes
git diff --staged           # Show staged changes
git blame <file>            # Show who changed what
```

## Undo & Reset
```bash
git reset <file>            # Unstage file
git reset --hard HEAD       # Discard all changes
git revert <commit>         # Revert commit
git reset --soft HEAD~1     # Undo last commit
git restore <file>          # Discard changes in file
```

## Stashing
```bash
git stash                   # Stash changes
git stash list              # List stashes
git stash pop               # Apply and remove stash
git stash apply             # Apply but keep stash
```

## Advanced
```bash
git cherry-pick <commit>    # Copy commit to current branch
git rebase -i HEAD~n        # Interactive rebase
git reflog                  # View reference history
git tag <name>              # Create tag
```

## Cleaning
```bash
git clean -n                # Show what will be cleaned
git clean -f                # Force clean untracked files
git clean -fd               # Clean directories too
```

## Common Workflows
```bash
# Create and switch to new feature branch
git checkout -b feature_branch

# Save work in progress
git stash
git checkout other_branch
git stash pop

# Update feature branch with main
git checkout main
git pull
git checkout feature_branch
git merge main

# Squash last n commits
git reset --soft HEAD~n
git commit -m "New message"
```

## Useful Aliases
Add to `~/.gitconfig`:
```ini
[alias]
    st = status
    co = checkout
    br = branch
    ci = commit
    lg = log --oneline
    last = log -1 HEAD
```