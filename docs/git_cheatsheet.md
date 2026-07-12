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


## Additional Notes
To perform a git pull operation that overwrites local changes, including deleting untracked files, the following steps can be taken:  
`git fetch origin` 

This command downloads the latest changes from the remote repository (aliased as origin by default) but does not merge them into your local branch.  

Reset your local branch to match the remote branch, discarding local changes:  
`git reset --hard origin/<branch_name>`

`git clean -fdx`  
The -f (force) option is necessary to remove files, and -d (directories) ensures that untracked directories are also removed. This command will delete any files or directories that are not tracked by Git in your local repository.
The -x option means "Don’t use the standard ignore rules (see gitignore(5)), but still use the ignore rules given with -e
options from the command line. This allows removing all untracked files, including build products. This
can be used (possibly in conjunction with git restore or git reset) to create a pristine working directory
to test a clean build."


# Clone the repo without checking out files
  git clone --no-checkout <repo-url> <local-dir>
  cd <local-dir>

  # Initialize sparse checkout
  git sparse-checkout init --cone

  # Set the directory you want
  git sparse-checkout set dockerphx01

  # Check out the files
  git checkout

  Option 2: Partial Clone with Filter

  # Clone with path-based filtering (Git 2.19+)
  git clone --filter=blob:none --sparse <repo-url> <local-dir>
  cd <local-dir>
  git sparse-checkout set dockerphx01

  Managing Updates

  Once set up, normal git operations work:
  git pull  # Only updates your sparse checkout directory
  git status
  git add dockerphx01/
  git commit -m "updates"
  git push

  The sparse checkout approach gives you a full git repository but only checks out the dockerphx01/ directory to your working tree, keeping the repo size minimal while maintaining full git functionality.