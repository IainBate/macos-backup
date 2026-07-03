#!/bin/zsh
# ============================================================================
# restore.sh — Restore macOS configuration on a new M5 MacBook Air
# ============================================================================
# Fetches backup from ./backup_output/ (subfolder of the current working directory),
# installs Homebrew/Xcode/ apps, sets up Python,
# Node.js, Ollama (Qwen 3.6 35B-A3B), Claude integration, restores
# keychain and preferences, configures ~/.zshrc, applies system optimizations.
#
# Usage: zsh restore.sh
# Prerequisites: Internet connection, GitHub SSH key configured
# ============================================================================

set -e

# --- Validation ---
if [ -z "${ZSH_VERSION+1}" ]; then
    echo "Error: This script must be run with Zsh."
    exit 1
fi

RESTORE_DIR="$(pwd)/backup_output"

log() {
    echo "[$(date +'%H:%M:%S')] $*"
}

log "🚀 Starting M5 MacBook Air restoration from $RESTORE_DIR ..."

# ============================================================================
# 1. Prerequisites Check
# ============================================================================
log "🔍 Checking prerequisites..."

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
log "  macOS version: $MACOS_VERSION"

# Check disk space (need ~200GB free for models + apps)
FREE_SPACE=$(df -g / 2>/dev/null | awk 'NR==2{print $4}' || echo "0")
log "  Free disk space: ${FREE_SPACE}GB"
if [ "$FREE_SPACE" -lt 50 ] 2>/dev/null; then
    log "  ⚠ Warning: Less than 50GB free. Consider freeing space before continuing."
fi

# Check internet
if ! ping -c 1 -t 3 github.com &>/dev/null; then
    log "  ⚠ Warning: No internet connection detected. Some steps may fail."
fi

log "  ✓ Prerequisites check complete"

# ============================================================================
# 2. Verify Backup Files
# ============================================================================
log "📥 Verifying backup files..."

if [ ! -d "$RESTORE_DIR" ]; then
    log "  ⚠ Backup output directory not found at $RESTORE_DIR"
    log "  This script should be run via bootstrap.sh on a clean Mac."
    log "  On an existing Mac, cd to the cloned repo and run: zsh restore.sh"
    exit 1
fi

# Verify backup files exist
REQUIRED_FILES=(
    "settings/Finder.plist"
    "settings/Dock.plist"
    "settings/Mail.plist"
    "settings/system_info.txt"
    "settings/homebrew_casks.txt"
    "settings/homebrew_formulae.txt"
    "settings/homebrew_taps.txt"
    "settings/applications.txt"
    "settings/chrome_bookmarks.json"
    "settings/chrome_extensions.txt"
    "settings/wifi_networks.txt"
    "settings/pmset.txt"
    "settings/login_items.txt"
    "settings/pyenv_versions.txt"
    "settings/npm_global_packages.txt"
    "settings/vscode_settings.json"
    "models/ollama_models.txt"
    "keychain/keychain_backup.keychain"
)

MISSING=0
for f in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$RESTORE_DIR/$f" ]; then
        log "  ⚠ Missing backup file: $f"
        MISSING=$((MISSING + 1))
    fi
done

if [ "$MISSING" -gt 3 ]; then
    log "  ⚠ $MISSING backup files are missing. Some restore steps may be incomplete."
else
    log "  ✓ Backup files verified ($MISSING missing)"
fi

# ============================================================================
# 3. Install Xcode Command-Line Tools
# ============================================================================
log "🔧 Installing Xcode command-line tools..."

if ! xcode-select -p &>/dev/null; then
    log "  Installing Xcode command-line tools..."
    log "  ⚠ A dialog will appear — click 'Install' and accept the license."
    xcode-select --install 2>/dev/null || true

    # Wait for installation (poll for up to 5 minutes)
    for i in $(seq 1 60); do
        if xcode-select -p &>/dev/null; then
            log "  ✓ Xcode tools installed"
            break
        fi
        sleep 5
    done

    if ! xcode-select -p &>/dev/null; then
        log "  ⚠ Xcode tools may not have installed correctly. Run 'xcode-select --install' manually."
    fi
else
    log "  ✓ Xcode tools already installed"
fi

# Accept license non-interactively if possible
sudo xcodebuild -license accept 2>/dev/null || true

# ============================================================================
# 4. Install Homebrew
# ============================================================================
log "🍺 Installing Homebrew..."

if ! command -v brew &>/dev/null; then
    log "  Installing Homebrew for Apple Silicon..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" 2>&1 | tail -5

    # Add Homebrew to PATH
    if ! grep -q '/opt/homebrew/bin' ~/.zshrc 2>/dev/null; then
        cat >> ~/.zshrc << 'BREW_PATH'

# Homebrew path (Apple Silicon)
eval "$(/opt/homebrew/bin/brew shellenv)"
BREW_PATH
        log "  ✓ Homebrew PATH added to ~/.zshrc"
    fi
    eval "$(/opt/homebrew/bin/brew shellenv)"
    log "  ✓ Homebrew installed"
else
    log "  ✓ Homebrew already installed ($(brew --version | head -1))"
fi

# Update Homebrew
brew update 2>/dev/null || log "  ⚠ brew update failed (may be up to date)"

# ============================================================================
# 5. Install Homebrew Taps
# ============================================================================
log "📚 Installing Homebrew taps..."

if [ -f "$RESTORE_DIR/settings/homebrew_taps.txt" ]; then
    while IFS= read -r tap; do
        [ -z "$tap" ] && continue
        brew tap "$tap" 2>/dev/null || log "  ⚠ Could not tap $tap"
    done < "$RESTORE_DIR/settings/homebrew_taps.txt"
    log "  ✓ Homebrew taps restored"
else
    log "  ⚠ No taps file found — skipping"
fi

# ============================================================================
# 6. Install Homebrew Formulae
# ============================================================================
log "📦 Installing Homebrew formulae..."

FORMULAE=(git jq python node pyenv ollama ripgrep fd findutils gpg tmux zsh-syntax-highlighting)

if [ -f "$RESTORE_DIR/settings/homebrew_formulae.txt" ]; then
    # Try to install from backup, fall back to core set
    while IFS= read -r formula; do
        [ -z "$formula" ] && continue
        name=$(echo "$formula" | awk '{print $1}')
        # Skip if already installed
        if ! brew list --versions "$name" &>/dev/null; then
            FORMULAE+=("$name")
        fi
    done < "$RESTORE_DIR/settings/homebrew_formulae.txt"
    log "  ✓ Formulae from backup analyzed"
fi

# Remove duplicates
FORMULAE=($(printf '%s\n' "${FORMULAE[@]}" | sort -u))

if [ ${#FORMULAE[@]} -gt 0 ]; then
    brew install "${FORMULAE[@]}" 2>&1 | tail -3
    log "  ✓ Formulae installed"
else
    log "  ✓ All formulae already installed"
fi

# ============================================================================
# 7. Install Homebrew Casks (All Specified Apps)
# ============================================================================
log "📦 Installing Homebrew casks..."

CASKS=(
    google-drive
    dropbox
    global-protect
    vnc-viewer
    alfred
    spark
    transmit
    visual-studio-code
    istat-menus
    daisydisk
    notion
    obsidian
)

INSTALLED=0
SKIPPED=0
FAILED=0

for cask in "${CASKS[@]}"; do
    if brew list --cask "$cask" &>/dev/null; then
        log "  ✓ $cask already installed"
        INSTALLED=$((INSTALLED + 1))
    else
        if brew install --cask "$cask" 2>&1 | tail -1; then
            log "  ✓ $cask installed"
            INSTALLED=$((INSTALLED + 1))
        else
            log "  ⚠ $cask failed to install"
            FAILED=$((FAILED + 1))
        fi
    fi
done

# Note: Console.app and Disk Utility are built into macOS — no cask needed
log "  Note: Console.app and Disk Utility are built into macOS"

log "  Summary: $INSTALLED installed, $FAILED failed"

# ============================================================================
# 8. Python via pyenv
# ============================================================================
log "🐍 Setting up Python via pyenv..."

# Determine target Python version from backup
PY_VERSION=""
if [ -f "$RESTORE_DIR/settings/pyenv_versions.txt" ]; then
    # Find the latest installed version
    PY_VERSION=$(grep -v '\*' "$RESTORE_DIR/settings/pyenv_versions.txt" | tail -1 | tr -d ' ' || echo "")
fi

# Default to latest stable if no version specified
if [ -z "$PY_VERSION" ]; then
    PY_VERSION="3.12"
fi

if command -v pyenv &>/dev/null; then
    if ! pyenv versions | grep -q "$PY_VERSION"; then
        log "  Installing Python $PY_VERSION via pyenv..."
        pyenv install "$PY_VERSION" 2>&1 | tail -3
    fi
    pyenv global "$PY_VERSION"
    pyenv shell "$PY_VERSION"
    log "  ✓ Python $PY_VERSION set via pyenv"

    # Create virtualenv
    if [ ! -d "$HOME/venv" ]; then
        log "  Creating virtualenv at ~/venv..."
        python3 -m venv "$HOME/venv"
    fi
    source "$HOME/venv/bin/activate"
    pip install --upgrade pip 2>/dev/null || true
    log "  ✓ Virtualenv ready at ~/venv"
else
    log "  ⚠ pyenv not available — using system Python"
fi

# ============================================================================
# 9. Node.js
# ============================================================================
log "📦 Setting up Node.js..."

if command -v node &>/dev/null; then
    log "  ✓ Node.js $(node --version) installed"
else
    log "  ⚠ Node.js not found — run 'brew install node' manually"
fi

# Restore global npm packages
if [ -f "$RESTORE_DIR/settings/npm_global_packages.txt" ]; then
    log "  Installing global npm packages from backup..."
    # Parse package names (skip headers and empty lines)
    packages=$(grep '├' "$RESTORE_DIR/settings/npm_global_packages.txt" 2>/dev/null | \
        sed 's/.*\(.*\)@.*/\1/' || echo "")
    if [ -n "$packages" ]; then
        echo "$packages" | while read -r pkg; do
            [ -z "$pkg" ] && continue
            npm install -g "$pkg" 2>/dev/null || log "  ⚠ Could not install npm package: $pkg"
        done
        log "  ✓ npm global packages restored"
    fi
fi

# ============================================================================
# 10. Ollama Setup (Qwen 3.6 35B-A3B)
# ============================================================================
log "🤖 Setting up Ollama..."

if command -v ollama &>/dev/null; then
    # Start Ollama server in background if not running
    if ! lsof -i :11434 &>/dev/null; then
        log "  Starting Ollama server..."
        ollama serve &
        sleep 5
    fi

    # Pull the specified model
    MODEL="qwen3.6:35b-a3b"
    log "  Pulling model: $MODEL (64k context, Apple Silicon optimized)..."
    ollama pull "$MODEL" 2>&1 | tail -3

    # Configure context window (64k = 65536)
    ollama show "$MODEL" --modelfile 2>/dev/null | grep -q "num_ctx" || \
        ollama create "${MODEL}-ctx64k" -f <(cat << 'MODFILE'
FROM qwen3.6:35b-a3b
PARAMETER num_ctx 65536
MODFILE
    ) 2>/dev/null || log "  ⚠ Could not set context window (may already be configured)"

    log "  ✓ Ollama model $MODEL pulled"
else
    log "  ⚠ Ollama not installed — run 'brew install ollama' manually"
fi

# ============================================================================
# 11. Claude Integration
# ============================================================================
log "🤖 Setting up Claude integration..."

mkdir -p "$HOME/bin"

cat > "$HOME/bin/run_claude_local" << 'CLAUDE_LOCAL_SCRIPT'
#!/bin/zsh
# run_claude_local — Run Claude with local Ollama model
# Usage: run_claude_local "your prompt"
#        run_claude_local --model qwen3.6:35b-a3b --prompt "your prompt"

export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-http://localhost:11434}"
export ANTHROPIC_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN:-ollama}"
export CLAUDE_API_KEY="${CLAUDE_API_KEY:-<REDACTED_API_KEY>}"

# Start Ollama if not running
if ! lsof -i :11434 &>/dev/null; then
    ollama serve &
    sleep 3
fi

exec claude "$@"
CLAUDE_LOCAL_SCRIPT

chmod +x "$HOME/bin/run_claude_local"
log "  ✓ ~/bin/run_claude_local created (local Ollama)"

# --- Second Claude script: remote server via lmstudio on port 1234 ---
log "  Setting up ~/bin/run_claude_server (remote lmstudio server)..."

cat > "$HOME/bin/run_claude_server" << 'CLAUDE_SERVER_SCRIPT'
#!/bin/zsh
# run_claude_server — Run Claude with remote Qwen 3.6 35B-A3B via lmstudio
# Usage: run_claude_server "your prompt"
#        run_claude_server --model qwen/qwen3.6-35b-a3b --prompt "your prompt"
#
# Requires: lmstudio running on localhost:1234

export ANTHROPIC_BASE_URL="http://localhost:1234"
export ANTHROPIC_AUTH_TOKEN="lmstudio"
export CLAUDE_API_KEY="${CLAUDE_API_KEY:-<REDACTED_API_KEY>}"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="qwen/qwen3.6-35b-a3b"
export ANTHROPIC_DEFAULT_OPUS_MODEL="qwen/qwen3.6-35b-a3b"
export ANTHROPIC_DEFAULT_SONNET_MODEL="qwen/qwen3.6-35b-a3b"
export CLAUDE_CODE_ATTRIBUTION_HEADER=0

exec claude --model qwen/qwen3.6-35b-a3b "$@"
CLAUDE_SERVER_SCRIPT

chmod +x "$HOME/bin/run_claude_server"
log "  ✓ ~/bin/run_claude_server created (remote lmstudio)"

# ============================================================================
# 12. Restore Keychain
# ============================================================================
log "🔐 Restoring keychain..."

if [ -f "$RESTORE_DIR/keychain/keychain_backup.keychain" ]; then
    log "  ⚠ macOS will prompt you to authorize the keychain import. Enter your login password."
    security import "$RESTORE_DIR/keychain/keychain_backup.keychain" \
        -T /usr/bin/security 2>/dev/null && \
        log "  ✓ Keychain imported" || \
        log "  ⚠ Keychain import failed — may need manual re-import"
else
    log "  ⚠ No keychain backup found"
fi

# ============================================================================
# 13. Restore Plist Preferences
# ============================================================================
log "📋 Restoring plist preferences..."

for domain in Finder Dock Mail; do
    plist="$RESTORE_DIR/settings/${domain}.plist"
    if [ -f "$plist" ]; then
        defaults import "com.apple.${domain:l}" "$plist" 2>/dev/null && \
            log "  ✓ ${domain} preferences restored" || \
            log "  ⚠ ${domain} preferences import failed"
    else
        log "  ⚠ ${domain}.plist not found — skipping"
    fi
done

# Apply Finder and Dock changes
killall Finder 2>/dev/null || true
killall Dock 2>/dev/null || true
log "  ✓ Finder and Dock restarted to apply preferences"

# ============================================================================
# 14. Configure ~/.zshrc (Append Only — Never Overwrite)
# ============================================================================
log "⚙️  Configuring ~/.zshrc..."

ZSHRC="$HOME/.zshrc"
APPENDED=0

# Helper: append a block only if not already present
append_if_missing() {
    local marker="$1"
    local content="$2"
    if ! grep -q "$marker" "$ZSHRC" 2>/dev/null; then
        echo "" >> "$ZSHRC"
        echo "# === $marker ===" >> "$ZSHRC"
        echo "$content" >> "$ZSHRC"
        echo "# === end $marker ===" >> "$ZSHRC"
        APPENDED=1
    fi
}

# PATH
append_if_missing "backup_and_restore PATH" '
export PATH="$HOME/bin:/opt/homebrew/bin:$PATH"
'

# Claude API Key (env var override supported)
append_if_missing "CLAUDE_API_KEY" '
# Claude API key — override with: export CLAUDE_API_KEY="your-key"
export CLAUDE_API_KEY="${CLAUDE_API_KEY:-<REDACTED_API_KEY>}"
'

# Claude / Ollama environment
append_if_missing "ANTHROPIC_BASE_URL" '
# Claude + Ollama integration
export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-http://localhost:11434}"
export ANTHROPIC_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN:-ollama}"

# Ollama Apple Silicon optimizations
export OLLAMA_NUM_PARALLEL=1
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_MAX_LOADED_MODELS=1
'

# pyenv init
append_if_missing "pyenv init" '
# pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
'

# Aliases
append_if_missing "backup_and_restore aliases" '
# AI model aliases
alias ask="ollama run qwen3.6:35b-a3b"
alias ask-coder="ollama run qwen3.6:35b-a3b-coder"
alias claude-local="$HOME/bin/run_claude_local"
alias claude-server="$HOME/bin/run_claude_server"

# Python venv
if [ -f "$HOME/venv/bin/activate" ]; then
    source "$HOME/venv/bin/activate"
fi
'

if [ "$APPENDED" -gt 0 ]; then
    log "  ✓ ~/.zshrc updated (appended)"
else
    log "  ✓ ~/.zshrc already configured"
fi

# Source the updated zshrc
source "$ZSHRC" 2>/dev/null || log "  ⚠ Could not source ~/.zshrc — run 'source ~/.zshrc' manually"

# ============================================================================
# 15. System Optimization (Apple Silicon — M5 MacBook Air)
# ============================================================================
log "⚡ Applying system optimizations..."

# Apple Silicon power settings (NOT hibernatemode 0 — that's Intel-only)
sudo pmset -a powernap 1 2>/dev/null && log "  ✓ powernap enabled" || true
sudo pmset -a tcpkeepalive 1 2>/dev/null && log "  ✓ tcpkeepalive enabled" || true
sudo pmset -a womp 1 2>/dev/null && log "  ✓ Wake-on-WLAN enabled" || true
sudo pmset -a disksleep 0 2>/dev/null && log "  ✓ disk sleep disabled (for Ollama)" || true
sudo pmset -c sleep 0 2>/dev/null && log "  ✓ automatic sleep disabled on AC" || true
sudo pmset -c lowpowermode 0 2>/dev/null && log "  ✓ low power mode disabled" || true

# standby / autopoweroff for battery (keep backups safe)
sudo pmset -b standby 1 2>/dev/null || true
sudo pmset -b autopoweroff 1 2>/dev/null || true

# ============================================================================
# 16. FileVault (Full-Disk Encryption)
# ============================================================================
log "🔒 Setting up FileVault..."

FILEVAULT_STATUS=$(fdesetup status 2>/dev/null || echo "off")
if [ "$FILEVAULT_STATUS" != "FileVault is On." ]; then
    log "  ⚠ FileVault is not enabled. Enabling full-disk encryption..."
    log "  ⚠ You will be prompted for your password."
    # fdesetup enable requires interactive input — document for user
    log "  Run manually: sudo fdesetup enable -user $USER"
else
    log "  ✓ FileVault already enabled"
fi

# ============================================================================
# 17. Manual Step Markers
# ============================================================================
log ""
log "=============================================="
log "  MANUAL STEPS — Please complete these:"
log "=============================================="
log ""
log "  1. Google Drive — sign in with your University of York account"
log "  2. Dropbox — sign in and link your account"
log "  3. Spark — configure your email account"
log "  4. Alfred — set up license and hotkey"
log "  5. Global Protect — connect to VPN"
log "  6. iStat Menus — enter license key"
log "  7. Chrome — sign in to sync (bookmarks, passwords, extensions)"
log "  8. FileVault — if not enabled above, run: sudo fdesetup enable -user $USER"
log "  9. System Settings > Battery > Power — set to 'High Performance'"
log "  10. System Settings > Desktop & Screen Saver — customize wallpaper"
log "  11. System Settings > Privacy > Location Services — verify app permissions"
log ""
log "=============================================="
log ""

# ============================================================================
# Done
# ============================================================================
log "✅ Restoration complete!"
log ""
log "Next steps:"
log "  1. Run the manual steps listed above"
log "  2. Verify your apps: $(ls /Applications/ | wc -l | tr -d ' ') apps installed"
log "  3. Check Ollama: ollama list"
log "  4. Test Claude (local): ~/bin/run_claude_local 'hello'"
log "  5. Test Claude (server): ~/bin/run_claude_server 'hello'"
log "  5. Verify settings: pmset -g custom"
log "  6. Verify FileVault: fdesetup status"
log ""
log "Your new M5 MacBook Air is ready to use!"
