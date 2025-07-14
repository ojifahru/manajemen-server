# Git Merge Conflict Resolution Guide

## Problem
```
error: Your local changes to the following files would be overwritten by merge:
install.sh
Please commit your changes or stash them before you merge.
```

## Solution Options

### Option 1: Commit Local Changes First
```bash
# Check current changes
git status

# Add changes to staging
git add .

# Commit changes
git commit -m "Local modifications to install.sh"

# Pull latest changes
git pull origin main

# If there are conflicts, resolve them manually
```

### Option 2: Stash Local Changes
```bash
# Stash current changes
git stash

# Pull latest changes
git pull origin main

# Apply stashed changes back
git stash pop

# Resolve any conflicts if they occur
```

### Option 3: Reset to Remote (CAREFUL - This will lose local changes)
```bash
# BACKUP your local changes first!
cp install.sh install.sh.backup

# Reset to remote
git reset --hard origin/main

# Pull latest
git pull origin main
```

### Option 4: View Differences First
```bash
# See what changes you have locally
git diff HEAD install.sh

# See what changes are coming from remote
git fetch origin main
git diff HEAD origin/main install.sh
```

## After Git Pull - Fix Permissions

After any git pull, you need to fix file permissions:

```bash
# Run the setup script
chmod +x setup-permissions.sh
./setup-permissions.sh
```

OR manually:

```bash
# Give execute permission to all shell scripts
chmod +x *.sh

# Verify permissions
ls -la *.sh
```

## Best Practices

1. **Always backup before major operations**
2. **Use stash for temporary changes**
3. **Commit meaningful changes**
4. **Set up permissions after clone/pull**
5. **Test scripts before deployment**

## Common Commands

```bash
# Check repository status
git status

# Check differences
git diff

# View commit history
git log --oneline

# Create backup
cp install.sh install.sh.$(date +%Y%m%d_%H%M%S)

# Set permissions for all shell scripts
find . -name "*.sh" -exec chmod +x {} \;
```
