# macOS Backup & Restore System

Automated migration toolkit for setting up a new M5 MacBook Air (32GB RAM, 1TB storage).

## Quick Start

### On your current Mac (backup):

```zsh
# Clone the repo (first time only)
git clone git@github.com:IainBate/backup_and_restore.git ~/backup_and_restore
cd ~/backup_and_restore

# Run the backup — files go to ./backup_output/ in whatever directory you run from
zsh backup.sh
```

This exports your macOS preferences, keychain, Wi-Fi networks, installed apps, Chrome data, and system state to `./backup_output/` (a subfolder of the directory you run the script from), then pushes everything to this git repo.

### On your new M5 MacBook Air (restore):

On a **clean Mac with no tools installed**, connect to Wi-Fi and paste this single command into Terminal:

```zsh
/usr/bin/env zsh -c "$(curl -fsSL https://raw.githubusercontent.com/IainBate/backup_and_restore/main/bootstrap.sh)"
```

This will:
1. Install Xcode Command-Line Tools (which includes git)
2. Clone this repo to `/tmp/backup_and_restore`
3. Run the restore script from there
4. Leave temporary files for macOS to clean up automatically

**Prerequisites:** Internet connection (Wi-Fi must be configured). The command only needs `curl`, which is built into macOS.

## Manual Steps (Required After Restore)

The script automates as much as possible, but these steps require your interaction:

| # | Step | Details |
|---|------|---------|
| 1 | Google Drive | Sign in with your University of York account |
| 2 | Dropbox | Sign in and link your account |
| 3 | Spark | Configure your email account |
| 4 | Alfred | Set up license and hotkey |
| 5 | Global Protect | Connect to VPN |
| 6 | iStat Menus | Enter license key |
| 7 | Chrome | Sign in to sync (bookmarks, passwords, extensions) |
| 8 | FileVault | Enable full-disk encryption if not done by script |
| 9 | Battery settings | System Settings > Battery > Power → "High Performance" |
| 10 | Desktop | Customize wallpaper in System Settings > Desktop & Screen Saver |
| 11 | Location Services | Verify app permissions in System Settings > Privacy |

## M5 MacBook Air Notes

- **Unified memory**: Apple Silicon's unified memory is hardware-managed — there is no manual toggle. The system manages RAM/GPU memory automatically.
- **Power settings**: The script uses Apple Silicon power settings (`powernap`, `lowpowermode`, `womp`). The old `hibernatemode 0` setting is Intel-only and does not apply.
- **Console.app & Disk Utility**: These are built into macOS — no Homebrew cask needed.

## Model Configuration

Two Claude scripts are created, each routing to a different Qwen 3.6 35B-A3B backend:

### `~/bin/run_claude_local` — Local Ollama (no internet required)

Routes through local Ollama on `localhost:11434`. Uses Apple Silicon optimizations:

```
export OLLAMA_NUM_PARALLEL=1
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_MAX_LOADED_MODELS=1
```

### `~/bin/run_claude_server` — Remote lmstudio server

Routes through a remote lmstudio instance on `localhost:1234`. Sets model aliases for all Claude model families:

```
export ANTHROPIC_BASE_URL=http://localhost:1234
export ANTHROPIC_AUTH_TOKEN=lmstudio
export ANTHROPIC_DEFAULT_HAIKU_MODEL="qwen/qwen3.6-35b-a3b"
export ANTHROPIC_DEFAULT_OPUS_MODEL="qwen/qwen3.6-35b-a3b"
export ANTHROPIC_DEFAULT_SONNET_MODEL="qwen/qwen3.6-35b-a3b"
export CLAUDE_CODE_ATTRIBUTION_HEADER=0
```

**Usage:**
```zsh
claude --model qwen/qwen3.6-35b-a3b          # via run_claude_local (local)
claude --model qwen/qwen3.6-35b-a3b          # via run_claude_server (remote)
```

## Directory Structure

The backup files are written to `./backup_output/` (a subfolder of the directory you run the script from):

```
<your working directory>/
├── backup.sh              # Run on old Mac
├── restore.sh             # Run on new Mac
├── .gitignore
├── README.md
├── backup_output/         # Created by backup.sh
│   ├── settings/
│   │   ├── Finder.plist       # Finder preferences
│   │   ├── Dock.plist         # Dock preferences
│   │   ├── Mail.plist         # Mail preferences
│   │   ├── wifi_networks.txt  # Wi-Fi SSIDs
│   │   ├── homebrew_casks.txt # Installed casks
│   │   ├── homebrew_formulae.txt
│   │   ├── homebrew_taps.txt
│   │   ├── applications.txt   # /Applications + ~/Applications
│   │   ├── chrome_bookmarks.json
│   │   ├── chrome_extensions.txt
│   │   ├── pmset.txt          # Power management settings
│   │   ├── login_items.txt
│   │   ├── pyenv_versions.txt
│   │   ├── npm_global_packages.txt
│   │   ├── vscode_settings.json
│   │   ├── system_info.txt
│   │   └── ...
│   ├── keychain/
│   │   └── keychain_backup.keychain
│   └── models/
│       └── ollama_models.txt
```

## Troubleshooting

- **Git clone fails**: Ensure your SSH key is configured: `ssh-keygen -t ed25519 && ssh-add ~/.ssh/id_ed25519`
- **Homebrew install fails**: Check your internet connection and run `brew doctor`
- **Ollama model fails to pull**: Ensure you have at least 20GB free disk space
- **Keychain import fails**: You may need to manually import via Keychain Access app
- **App Store apps**: Install `mas` first: `brew install mas`, then `mas list` to see purchased apps
