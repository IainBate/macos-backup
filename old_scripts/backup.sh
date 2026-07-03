#!/bin/zsh

# 1. Create backup folder structure
mkdir -p ~/backup_and_restore/{apps,settings,backup,keychain,models}

# 2. Export system settings
defaults export com.apple.finder ~/backup_and_restore/settings/Finder.plist
defaults export com.apple.dock ~/backup_and_restore/settings/Dock.plist
defaults export com.apple.mail ~/backup_and_restore/settings/Mail.plist

# 3. Export keychain (you'll need to enter your keychain password)
security export -k ~/Library/Keychains/login.keychain.d -o ~/backup_and_restore/keychain/keychain_backup.keychain

# 4. Export Wi-Fi passwords (requires sudo)
sudo security dump-keychain -p | grep -i "Wi-Fi" > ~/backup_and_restore/settings/wifi_passwords.txt

# 5. Export iCloud settings (requires icloudpd - install it first)
# (This is optional and not fully automated, but you can run it separately)
# pip install icloudpd
# icloudpd --username=your@apple.com --password=yourpassword --output=~/backup_and_restore/icloud_backup

# 6. Pull Ollama models and list them
ollama list > ~/backup_and_restore/models.txt
ollama pull qwen3.5:35b-instruct
ollama pull qwen3.5-coder:35b-instruct-q4_K_M

# 7. Push to GitHub
cd ~/backup_and_restore
git init
git add .
git commit -m "Backup of macOS settings and models"
git remote add origin git@github.com:IainBate/backup_and_restore.git
git push -u origin master

