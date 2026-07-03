#!/bin/zsh

# Script Name: backup_osx.sh
# Description: Generates the updated M5 restore script, exports settings, and pushes to Git
# License: MIT

if [ -z "${ZSH_VERSION+1}" ]; then
    echo "Error: This script must be run with Zsh."
    exit 1
fi

BACKUP_DIR="$HOME/MigrationBackup"
LOG_FILE="$BACKUP_DIR/backup.log"

mkdir -p "$BACKUP_DIR"

log() {
    printf "[%s] %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
    echo "$*"
}

error_cleanup() {
    log "❌ Backup process failed. Check $LOG_FILE for details."
    exit 1
}

trap error_cleanup ERR

log "🚀 Starting updated system backup and script generation..."

# --- 1. Export User Preferences ---
log "Exporting macOS application plist preferences..."
defaults export com.apple.finder "$BACKUP_DIR/Finder.plist"
defaults export com.apple.dock "$BACKUP_DIR/Dock.plist"
defaults export com.apple.mail "$BACKUP_DIR/Mail.plist"

# --- 2. Export Encrypted Login Keychain ---
log "Exporting secure system login keychain..."
if [ -f "$HOME/Library/Keychains/login.keychain-db" ]; then
    KEYCHAIN_SRC="$HOME/Library/Keychains/login.keychain-db"
else
    KEYCHAIN_SRC="$HOME/Library/Keychains/login.keychain"
fi

log "⚠️ macOS will now prompt you to authorize the secure export. Please enter your login password."
security export -k "$KEYCHAIN_SRC" -o "$BACKUP_DIR/keychain_backup.keychain"

# --- 3. Save Wi-Fi Audit Instructions ---
log "Documenting network audit notes..."
cat << 'EOF' > "$BACKUP_DIR/wifi_instructions.txt"
--- Wi-Fi Passwords Audit Note ---
To pull specific Wi-Fi passwords manually, execute this command in terminal:
security find-generic-password -a "YourName" -s "Wi-Fi Network Name"
EOF

# --- 4. DYNAMICALLY GENERATE EMBEDDED RESTORE_OSX.SH ---
log "Generating the optimized backup_and_restore.sh script for your new M5..."

cat << 'EOF' > "$BACKUP_DIR/backup_and_restore.sh"
#!/bin/zsh

# Script Name: backup_and_restore.sh
# Description: Automated M5 MacBook system restoration and optimization
# License: MIT

if [ -z "${ZSH_VERSION+1}" ]; then
    echo "Error: This script must be run with Zsh."
    exit 1
fi

LOG_FILE="$HOME/MigrationBackup/migration.log"

log() {
    printf "[%s] %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
    echo "$*"
}

cleanup() {
    log "❌ An error occurred during restoration. Script halted."
    exit 1
}

trap cleanup ERR

log "🚀 Starting M5 System Setup and Migration Restore Workflow..."

# --- 1. Hardware & System Performance Optimization ---
log "Configuring M5 High-Performance Power Allocations..."
sudo pmset -c servermode 1

log "Triggering Xcode Command Line Tools installation..."
if ! xcode-select -p &>/dev/null; then
    xcode-select --install
    log "Please accept the Xcode license prompt if visible before continuing."
fi

# --- 2. Install Homebrew ---
if ! command -v brew &> /dev/null; then
    log "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --- 3. Install Package Formulae & Casks ---
log "Installing specified Homebrew Formulae..."
brew install git jq mas python node ollama

log "Installing specified Homebrew Casks..."
brew install --cask google-chrome firefox dropbox vnc-viewer global-protect \
                    visual-studio-code alfred spark transmit google-drive \
                    istat-menus daisydisk notion obsidian

# --- 4. Python & Development Setup ---
log "Setting up isolated Python 3 environment..."
python3 -m venv ~/venv
source ~/venv/bin/activate
pip install --upgrade pip
pip install virtualenv ipython jupyter

# --- 5. Ollama Model Management ---
log "Pulling localized AI Models..."
ollama serve & 
sleep 5 
ollama pull qwen3.5:35b-instruct
ollama pull qwen3.5-coder:35b-instruct-q4_K_M

# --- 6. Create Local Claude Executable Wrapper (No Internet Configuration) ---
log "Creating offline Claude routing script in ~/bin/run_claude..."
mkdir -p "$HOME/bin"

cat << 'CLAUDE_EOF' > "$HOME/bin/run_claude"
#!/bin/zsh
# Generated via backup_and_restore.sh - Local Offline Claude Integration Wrapper
export OLLAMA_HOST="127.0.0.1:11434"

if [ $# -eq 0 ]; then
    log "Opening interactive session with local offline model..."
    ollama run qwen3.5:35b-instruct
else
    ollama run qwen3.5:35b-instruct "$@"
fi
CLAUDE_EOF

chmod +x "$HOME/bin/run_claude"

# --- 7. Security & Core System Restores ---
log "Restoring Keychain & Encryption settings..."
if [ -f "$HOME/MigrationBackup/keychain_backup.keychain" ]; then
    security import "$HOME/MigrationBackup/keychain_backup.keychain" -T /usr/bin/security
fi

FILEVAULT_PASSWORD=$(osascript -e 'display dialog "Enter your FileVault password to enforce full disk encryption:" default answer "" with title "Security Setup"')
FILEVAULT_PASSWORD="${FILEVAULT_PASSWORD##*: }"
sudo fdesetup enable -user "$USER" -passphrase "$FILEVAULT_PASSWORD"

# --- 8. User Preference Plist Imports ---
log "Restoring macOS application and environment preferences..."
for domain in Finder Dock Mail; do
    if [ -f "$HOME/MigrationBackup/${domain}.plist" ]; then
        defaults import "com.apple.${domain:l}" "$HOME/MigrationBackup/${domain}.plist"
        log "Successfully imported com.apple.${domain:l} preferences."
    fi
done

# --- 9. Shell Configuration Generation ---
log "Generating unified shell profile settings (~/.zshrc)..."
cat << 'SHELL_EOF' > ~/.zshrc
# Environment Paths
export PATH="$HOME/bin:/opt/homebrew/bin:$PATH"
export EDITOR='vim'
export PAGER='less'
export HOMEBREW_NO_INSTALL_REDIRECT=true

# Claude AI Integration Properties (Spec-compliant Sandbox Key)
export CLAUDE_API_KEY="<REDACTED_API_KEY>"

# Ollama Apple Silicon Hardware Memory Enhancements
export OLLAMA_NUM_PARALLEL=1
export OLLAMA_FLASH_ATTENTION=1

# Localized AI Shortcuts
alias ask="ollama run qwen3.5:35b-instruct"
alias ask-coder="ollama run qwen3.5-coder:35b-instruct-q4_K_M"
alias claude="$HOME/bin/run_claude"

# Python VirtualEnv Autostart
source ~/venv/bin/activate
SHELL_EOF

source ~/.zshrc

log "✅ Migration and Configuration Sequence Complete!"
EOF

# Make the newly generated restore script executable locally
chmod +x "$BACKUP_DIR/backup_and_restore.sh"

# --- 5. Initialize Git Version Control & Push ---
log "Setting up Git repository tracking..."
cd "$BACKUP_DIR"

if [ ! -d ".git" ]; then
    git init
    git branch -M main
    git remote add origin git@github.com:IainBate/backup_and_restore.git
fi

git add .
git commit -m "Automated backup capture with offline Claude binary patch: $(date +'%Y-%m-%d %H:%M:%S')"

log "=================================================================="
log "✅ Local Backup & Setup Script Generated Successfully!"
log "=================================================================="
echo ""
echo "Execute this last command to push everything up to GitHub:"
echo ""
echo "   cd $BACKUP_DIR && git push -u origin main"
echo ""