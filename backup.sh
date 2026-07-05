#!/bin/zsh
# ============================================================================
# backup.sh — Backup macOS configuration for M5 MacBook Air migration
# ============================================================================
# Exports system preferences, keychain, Wi-Fi info, installed apps,
# Chrome data, and system state to ./backup_output/, then pushes to git.
#
# Usage: zsh backup.sh
# Output: ./backup_output/ (pushed to git@github.com:IainBate/macos-backup.git)
# ============================================================================

set -e

# --- Validation ---
if [ -z "${ZSH_VERSION+1}" ]; then
    echo "Error: This script must be run with Zsh."
    exit 1
fi

BACKUP_DIR="$(pwd)/backup_output"
mkdir -p "$BACKUP_DIR"/{settings,keychain,models}

log() {
    echo "[$(date +'%H:%M:%S')] $*"
}

log "🚀 Starting macOS backup to $BACKUP_DIR ..."

# ============================================================================
# 1. Export macOS Plist Preferences
# ============================================================================
log "📋 Exporting macOS plist preferences..."

defaults export com.apple.finder "$BACKUP_DIR/settings/Finder.plist" 2>/dev/null && \
    log "  ✓ Finder preferences" || log "  ⚠ Finder preferences not available"

defaults export com.apple.dock "$BACKUP_DIR/settings/Dock.plist" 2>/dev/null && \
    log "  ✓ Dock preferences" || log "  ⚠ Dock preferences not available"

defaults export com.apple.mail "$BACKUP_DIR/settings/Mail.plist" 2>/dev/null && \
    log "  ✓ Mail preferences" || log "  ⚠ Mail preferences not available"

# Login items
osascript -e 'tell application "System Events" to get name of every login item' \
    > "$BACKUP_DIR/settings/login_items.txt" 2>/dev/null && \
    log "  ✓ Login items" || log "  ⚠ Login items not available"

# Spotlight exclusions
mdutil -s / > "$BACKUP_DIR/settings/spotlight_exclusions.txt" 2>/dev/null || true

# ============================================================================
# 2. Export Keychain
# ============================================================================
log "🔐 Exporting login keychain..."

if [ -f "$HOME/Library/Keychains/login.keychain-db" ]; then
    KEYCHAIN_SRC="$HOME/Library/Keychains/login.keychain-db"
elif [ -f "$HOME/Library/Keychains/login.keychain" ]; then
    KEYCHAIN_SRC="$HOME/Library/Keychains/login.keychain"
else
    log "  ⚠ No login keychain found — skipping keychain export"
    KEYCHAIN_SRC=""
fi

if [ -n "$KEYCHAIN_SRC" ]; then
    log "  Copying login keychain to backup..."
    cp -p "$KEYCHAIN_SRC" "$BACKUP_DIR/keychain/keychain_backup.keychain-db" && \
        log "  ✓ Keychain exported" || log "  ⚠ Keychain export failed"
fi

# ============================================================================
# 3. Capture Wi-Fi Networks
# ============================================================================
log "📶 Capturing Wi-Fi network names..."

wifi_list=""
for iface in $(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $0}'); do
    ssid=$(networksetup -getairportnetwork "$iface" 2>/dev/null | sed 's/.*: //')
    if [ "$ssid" != "Off" ] && [ -n "$ssid" ]; then
        wifi_list="${wifi_list}${ssid}\n"
    fi
done
if [ -n "$wifi_list" ]; then
    printf "%b" "$wifi_list" | sort -u > "$BACKUP_DIR/settings/wifi_networks.txt"
    log "  ✓ Wi-Fi networks saved ($(wc -l < "$BACKUP_DIR/settings/wifi_networks.txt") networks)"
else
    log "  ⚠ No Wi-Fi networks found"
fi

# ============================================================================
# 4. List Installed Applications
# ============================================================================
log "📦 Capturing installed applications..."

# Homebrew casks
if command -v brew &>/dev/null; then
    brew list --cask --versions 2>/dev/null > "$BACKUP_DIR/settings/homebrew_casks.txt" || true
    brew list --formula --versions 2>/dev/null > "$BACKUP_DIR/settings/homebrew_formulae.txt" || true
    brew tap 2>/dev/null > "$BACKUP_DIR/settings/homebrew_taps.txt" || true
    log "  ✓ Homebrew casks and formulae captured"
else
    log "  ⚠ Homebrew not installed — skipping Homebrew capture"
fi

# App Store apps (requires mas)
if command -v mas &>/dev/null; then
    mas list 2>/dev/null > "$BACKUP_DIR/settings/appstore_apps.txt" || true
    log "  ✓ App Store apps captured"
else
    log "  ⚠ mas not installed — skipping App Store capture (run: brew install mas)"
fi

# /Applications and ~/Applications
{
    echo "=== /Applications ==="
    ls -1 /Applications 2>/dev/null
    echo "=== ~/Applications ==="
    ls -1 ~/Applications 2>/dev/null
} > "$BACKUP_DIR/settings/applications.txt"
log "  ✓ Applications directories captured"

# ============================================================================
# 5. Capture Chrome Bookmarks and Extensions
# ============================================================================
log "🌐 Capturing Chrome data..."

CHROME_BOOKMARKS="$HOME/Library/Application Support/Google/Chrome/Default/Bookmarks"
if [ -f "$CHROME_BOOKMARKS" ]; then
    cp "$CHROME_BOOKMARKS" "$BACKUP_DIR/settings/chrome_bookmarks.json"
    log "  ✓ Chrome bookmarks saved"
else
    log "  ⚠ Chrome bookmarks not found (Chrome may not be installed)"
fi

CHROME_EXTENSIONS="$HOME/Library/Application Support/Google/Chrome/Default/Extensions"
if [ -d "$CHROME_EXTENSIONS" ]; then
    ls -1 "$CHROME_EXTENSIONS" > "$BACKUP_DIR/settings/chrome_extensions.txt" 2>/dev/null
    log "  ✓ Chrome extensions list saved ($(wc -l < "$BACKUP_DIR/settings/chrome_extensions.txt") extensions)"
else
    log "  ⚠ Chrome extensions directory not found"
fi

# ============================================================================
# 6. Capture System State
# ============================================================================
log "⚙️  Capturing system state..."

# Ollama models
if command -v ollama &>/dev/null; then
    ollama list > "$BACKUP_DIR/models/ollama_models.txt" 2>/dev/null || true
    log "  ✓ Ollama models captured"
else
    log "  ⚠ Ollama not installed"
fi

# MLX models
MLX_MODELS_DIR="$HOME/.mlx/models/mlx-community"
if [ -d "$MLX_MODELS_DIR" ]; then
    mkdir -p "$BACKUP_DIR/models/mlx_models"
    # List all MLX models with sizes
    find "$MLX_MODELS_DIR" -name '*.safetensors' -exec du -sh {} \; 2>/dev/null > "$BACKUP_DIR/models/mlx_models.txt" || true
    # Save manifest
    find "$MLX_MODELS_DIR" -maxdepth 2 -type d -name '*' 2>/dev/null | while read -r d; do
        echo "$d" | sed "s|$MLX_MODELS_DIR/||"
    done > "$BACKUP_DIR/models/mlx_models_manifest.txt" 2>/dev/null || true
    log "  ✓ MLX models captured ($(wc -l < "$BACKUP_DIR/models/mlx_models_manifest.txt" 2>/dev/null || echo 0) models)"
else
    log "  ⚠ No MLX models found at $MLX_MODELS_DIR"
fi

# pmset settings
pmset -g custom > "$BACKUP_DIR/settings/pmset.txt" 2>/dev/null || true

# pyenv versions
if command -v pyenv &>/dev/null; then
    pyenv versions --short 2>/dev/null > "$BACKUP_DIR/settings/pyenv_versions.txt" || true
    log "  ✓ pyenv versions captured"
else
    log "  ⚠ pyenv not installed"
fi

# npm global packages
if command -v npm &>/dev/null; then
    npm list -g --depth=0 2>/dev/null > "$BACKUP_DIR/settings/npm_global_packages.txt" || true
    log "  ✓ npm global packages captured"
else
    log "  ⚠ npm not installed"
fi

# VS Code settings (if installed)
VSCODE_SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"
if [ -f "$VSCODE_SETTINGS" ]; then
    cp "$VSCODE_SETTINGS" "$BACKUP_DIR/settings/vscode_settings.json"
    log "  ✓ VS Code settings saved"
else
    log "  ⚠ VS Code settings not found"
fi

VSCODE_EXTENSIONS="$HOME/Library/Application Support/Code/User/globalStorage/state.vscde"
if [ -d "$VSCODE_EXTENSIONS" ]; then
    ls -1R "$VSCODE_EXTENSIONS" > "$BACKUP_DIR/settings/vscode_state.txt" 2>/dev/null || true
    log "  ✓ VS Code state captured"
fi

# Keybindings
if [ -f "$HOME/Library/Preferences/com.apple.keyboard.preferences.plist" ]; then
    defaults read com.apple.keyboard.preferences > "$BACKUP_DIR/settings/keybindings.txt" 2>/dev/null || true
    log "  ✓ Keybindings captured"
fi

# ============================================================================
# 7. System Info Summary
# ============================================================================
log "📊 Capturing system info..."

{
    echo "=== System Info ==="
    echo "Date: $(date)"
    echo "Hostname: $(hostname)"
    echo "Model: $(system_profiler SPHardwareDataType 2>/dev/null | grep 'Model Name' | sed 's/.*: //')"
    echo "Chip: $(system_profiler SPHardwareDataType 2>/dev/null | grep 'Chip' | sed 's/.*: //')"
    echo "RAM: $(system_profiler SPHardwareDataType 2>/dev/null | grep 'Memory' | sed 's/.*: //')"
    echo "macOS: $(sw_vers -productVersion)"
    echo "Build: $(sw_vers -buildVersion)"
    echo ""
    echo "=== Disk Usage ==="
    df -h / 2>/dev/null
    echo ""
    echo "=== Current User ==="
    echo "$USER"
} > "$BACKUP_DIR/settings/system_info.txt"

# ============================================================================
# 7.5 Sync all git repos under $HOME to their remotes
# ============================================================================
log "🔄 Syncing git repos under $HOME..."

REPO_MANIFEST="$BACKUP_DIR/settings/repo_manifest.txt"
> "$REPO_MANIFEST"

sync_repos() {
    local home="$1"
    local synced=0

    for dir in "$home"/*/; do
        [ -d "$dir" ] || continue
        [ -d "$dir/.git" ] || continue

        local repo_name
        repo_name=$(basename "$dir")
        local repo_url
        repo_url=$(cd "$dir" && git remote get-url origin 2>/dev/null || echo "")

        if [ -z "$repo_url" ]; then
            log "  ⚠ $repo_name: no origin remote — skipping"
            continue
        fi

        cd "$dir"

        # Determine branch (needed for manifest and push)
        local branch
        branch=$(git branch --show-current 2>/dev/null || echo "main")

        # Commit any uncommitted changes
        if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
            log "  ✓ $repo_name: up to date"
        else
            git add -A -- ':!backup_output/' 2>/dev/null || git add -A 2>/dev/null
            if git diff --cached --quiet; then
                log "  ✓ $repo_name: no changes to commit"
            else
                git commit -m "auto backup: $(date +'%Y-%m-%d %H:%M:%S')" 2>/dev/null || {
                    log "  ⚠ $repo_name: commit failed — check for merge conflicts"
                    continue
                }
                log "  ✓ $repo_name: committed"
            fi

            # Push to remote
            if git push origin "$branch" 2>&1 | tail -1; then
                log "  ✓ $repo_name: pushed"
            else
                log "  ⚠ $repo_name: push failed — check SSH keys and remote access"
            fi
        fi

        # Record for manifest (repo path, remote URL, branch)
        echo "$dir|$repo_url|$branch" >> "$REPO_MANIFEST"
        synced=$((synced + 1))
    done

    log "  Synced $synced repo(s) under $home"
}

sync_repos "$HOME"

# ============================================================================
# 8. Commit backup files to parent repo
# ============================================================================
log "📤 Committing to git..."

cd "$SCRIPT_DIR"

git add -A
git diff --cached --quiet || \
    git commit -m "Backup capture: $(date +'%Y-%m-%d %H:%M:%S')" || \
    log "  ⚠ No changes to commit"

# Try to push (will fail if not on a new machine with no upstream)
if git push origin main; then
    log "  ✓ Pushed to git"
else
    log "  ⚠ Push failed — check SSH keys and remote access"
fi

log ""
log "✅ Backup complete!"
log ""
log "Files saved to: $BACKUP_DIR"
log "To restore on your new Mac, run:"
log "  git clone git@github.com:IainBate/macos-backup.git ~/macos-backup"
log "  cd ~/macos-backup && zsh restore.sh"
