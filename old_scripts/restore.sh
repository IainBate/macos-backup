#!/bin/zsh

# 1. Pull from GitHub
cd ~/backup_and_restore
git pull origin master

# 2. Import system settings
defaults import com.apple.finder ~/backup_and_restore/settings/Finder.plist
defaults import com.apple.dock ~/backup_and_restore/settings/Dock.plist
defaults import com.apple.mail ~/backup_and_restore/settings/Mail.plist

# 3. Import keychain (you'll need to enter your keychain password)
security import ~/backup_and_restore/keychain/keychain_backup.keychain -P

# 4. Restore Wi-Fi passwords (requires sudo)
sudo security add-generic-password -a "Wi-Fi" -s "WiFi" -w $(cat ~/backup_and_restore/settings/wifi_passwords.txt) -t "inet" -U

# 5. Restore iCloud settings (optional, requires icloudpd)
# (This is optional and not fully automated, but you can run it separately)
# pip install icloudpd
# icloudpd --username=your@apple.com --password=yourpassword --output=~/backup_and_restore/icloud_backup

# 6. Install all apps via Homebrew Cask
brew install --cask google-drive dropbox globalprotect vnc-viewer alfred spark transmit visual-studio-code istat-menus daisydisk notion obsidian

# 7. Set up Ollama models
ollama pull qwen3.5:35b-instruct
ollama pull qwen3.5-coder:35b-instruct-q4_K_M
ollama set --default qwen3.5:35b-instruct

# 8. Configure Claude API key
echo 'export CLAUDE_API_KEY="sk-ant-api03-..."'>> ~/.zshrc
source ~/.zshrc

# 9. Apply system settings
# Enable unified memory (if not already enabled)
sudo pmset -a standbydelay 86400
sudo pmset -a autopoweroff 0
sudo pmset -a hibernatemode 0

# Set power settings
sudo pmset -a darkwakes 1
sudo pmset -a standby 1

# 10. Final steps: Sync accounts manually (e.g., Google Drive with University of York)
# This requires user interaction and cannot be automated in script

