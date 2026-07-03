#!/bin/zsh
# ============================================================================
# bootstrap.sh — Bootstrap a clean Mac with backup_and_restore tools
# ============================================================================
# Run this on a brand-new Mac (or one without git installed).
# It installs Xcode CLT (which includes git), clones this repo to /tmp,
# and runs restore.sh from there.
#
# Usage: /usr/bin/env zsh -c "$(curl -fsSL https://raw.githubusercontent.com/IainBate/backup_and_restore/main/bootstrap.sh)"
#
# Prerequisites: Internet connection (Wi-Fi must be configured)
# ============================================================================

set -e

log() {
    echo "[$(date +'%H:%M:%S')] $*"
}

# --- Step 1: Check internet ---
log "🔍 Checking internet connection..."
if ! ping -c 1 -t 3 github.com &>/dev/null; then
    log "  ⚠ No internet connection detected."
    log "  Please connect to Wi-Fi first, then run this script again."
    exit 1
fi
log "  ✓ Internet connection OK"

# --- Step 2: Install Xcode Command-Line Tools (includes git) ---
log "🔧 Checking for git..."

if command -v git &>/dev/null; then
    log "  ✓ git is already installed ($(git --version))"
else
    log "  ⚠ git not found — installing Xcode Command-Line Tools..."
    log "  ⚠ A dialog will appear — click 'Install' and accept the license."

    if ! xcode-select --install &>/dev/null; then
        log "  ⚠ Xcode CLT installation may have failed."
        log "  Try: xcode-select --install"
        exit 1
    fi

    # Wait for installation (poll for up to 5 minutes)
    for i in $(seq 1 60); do
        if command -v git &>/dev/null; then
            log "  ✓ git installed ($(git --version))"
            break
        fi
        sleep 5
    done

    if ! command -v git &>/dev/null; then
        log "  ⚠ git may not have installed correctly."
        log "  Try: xcode-select --install"
        exit 1
    fi
fi

# Accept Xcode license
sudo xcodebuild -license accept 2>/dev/null || true

# --- Step 3: Clone repo to /tmp ---
log "📥 Cloning backup_and_restore to /tmp..."

BOOTSTRAP_DIR="/tmp/backup_and_restore"

# Clean up any previous bootstrap
if [ -d "$BOOTSTRAP_DIR" ]; then
    log "  Removing previous bootstrap directory..."
    rm -rf "$BOOTSTRAP_DIR"
fi

git clone git@github.com:IainBate/backup_and_restore.git "$BOOTSTRAP_DIR" 2>/dev/null || {
    log "  ⚠ Git clone failed. Make sure your SSH key is configured."
    log "  Try: ssh-keygen -t ed25519 && ssh-add ~/.ssh/id_ed25519"
    exit 1
}

log "  ✓ Cloned to $BOOTSTRAP_DIR"

# --- Step 4: Run restore ---
log "🚀 Running restore.sh..."
log ""
log "  The restore script will:"
log "    1. Install Homebrew and Xcode CLI tools"
log "    2. Install all specified apps"
log "    3. Set up Python, Node.js, Ollama, Claude"
log "    4. Restore keychain and macOS preferences"
log "    5. Configure ~/.zshrc"
log ""
log "  Backup files will be read from: $BOOTSTRAP_DIR/backup_output/"
log "  (Ensure your backup files are in the cloned repo before running.)"
log ""

cd "$BOOTSTRAP_DIR"
zsh restore.sh

# --- Step 5: Cleanup ---
log ""
log "✅ Restore complete!"
log ""
log "  Temporary files at $BOOTSTRAP_DIR will be auto-cleaned by macOS."
log "  You can also remove them manually: rm -rf $BOOTSTRAP_DIR"
