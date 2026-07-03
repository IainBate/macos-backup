#!/bin/bash
# Backup/Restore Script for macOS

REPO_DIR=/Users/iain/backup_and_restore

# --- Backup Section ---
function backup() {
  echo "Initializing git repository..."
  mkdir -p $REPO_DIR
  cd $REPO_DIR
  git init
  git config --global user.name "Iain"
  git config --global user.email "iain@example.com"

  # Create backup directory structure
  mkdir -p backups/{keychain,defaults,apps}

  # Backup keychain
  security export -k ~/Library/Keychains/login.keychain.d -o $REPO_DIR/backups/keychain_backup.keychain

  # Backup defaults
  defaults export com.apple.finder $REPO_DIR/backups/Finder.plist
  defaults export com.apple.dock $REPO_DIR/backups/Dock.plist
  defaults export com.apple.mail $REPO_DIR/backups/Mail.plist

  # Backup Wi-Fi passwords
  security find-generic-password -a "Iain" -s "Wi-Fi Network Name" > $REPO_DIR/backups/wifi_passwords.txt

  # Backup iCloud settings (manual step required in System Settings)
  echo "Backup iCloud settings manually in System Settings > Privacy > Location Services"

  # Backup Apple ID settings (manual export required)
  echo "Export Apple ID settings manually via System Settings"

  # Backup git repository
  git add .
  git commit -m "Initial backup"
  git remote add origin git@github.com:iain/backup_and_restore.git
  git push -u origin master
}

# --- Restore Section ---
function restore() {
  echo "Cloning repository..."
  git clone git@github.com:iain/backup_and_restore.git $REPO_DIR
  cd $REPO_DIR

  # Restore keychain
  security import $REPO_DIR/backups/keychain_backup.keychain -P "your_keychain_password"

  # Restore defaults
  defaults import com.apple.finder $REPO_DIR/backups/Finder.plist
  defaults import com.apple.dock $REPO_DIR/backups/Dock.plist
  defaults import com.apple.mail $REPO_DIR/backups/Mail.plist

  # Restore Wi-Fi passwords
  cat $REPO_DIR/backups/wifi_passwords.txt | security add-generic-password -a "Iain" -s "Wi-Fi Network Name"

  # Install Homebrew if not present
  if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  # Install apps via Homebrew Cask
  brew install --cask google-drive dropbox global-protect vnc-viewer alfred spark transmit visual-studio-code istat-menus daisydisk

  # Install Python/Node.js
  brew install python node

  # Install Ollama
  brew install ollama
  ollama pull qwen3.5:35b-instruct
  ollama pull qwen3.5-coder:35b-instruct-q4_K_M
  ollama set --default qwen3.5:35b-instruct

  # Configure Claude
  echo "export CLAUDE_API_KEY=<REDACTED_API_KEY>" >> ~/.zshrc
  source ~/.zshrc

  # Create run_claude script
  mkdir -p ~/bin
  echo "#!/bin/bash
ollama run qwen3.5:35b-instruct" > ~/bin/run_claude
  chmod +x ~/bin/run_claude

  # System optimizations
  sudo pmset -a standbydelay 86400
  sudo pmset -a hibernatemode 0
  launchctl unload -w /System/Library/LaunchDaemons/com.apple.iCloudHelper.plist
}

# --- Main Execution ---
if [ "$1" == "backup" ]; then
  backup
elif [ "$1" == "restore" ]; then
  restore
else
  echo "Usage: $0 [backup|restore]"
fi