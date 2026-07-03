# Portability Guide

This file documents what you need to know when moving, renaming, or copying
this folder to a new machine or location.

## What to Update When Moving

### 1. Git Remote URL
Both `backup.sh` (line 230) and `restore.sh` (line 59) reference:
```
git@github.com:IainBate/backup_and_restore.git
```
If you rename the repo or change the GitHub account, update these lines in both scripts.

### 2. API Keys
The following hardcoded API key appears in `restore.sh`:
- **CLAUDE_API_KEY** (lines 360, 387, 464) — `sk-ant-api03-...`

**Recommendation:** Replace with an environment variable prompt or a `.env` file
that is gitignored. Never commit real API keys.

### 3. GitHub Repository
This project expects to push to `git@github.com:IainBate/backup_and_restore.git`.
If you move to a different repo:
- Update the remote in both `backup.sh` and `restore.sh`
- Update this README's Quick Start section
- Update the `git clone` URLs

### 4. App-Specific Credentials
The restore script installs apps but does **not** store their credentials:
- Google Drive, Dropbox, Spark, Alfred, iStat Menus — require manual sign-in
- Chrome bookmarks are backed up, but passwords require Chrome sync
- Keychain backup is included but requires macOS authorization on import

## External Dependencies

| Dependency | Required? | How It's Used |
|------------|-----------|---------------|
| Git | Yes | Repo management, backup push/pull |
| Zsh | Yes | Both scripts require `#!/bin/zsh` |
| Homebrew | Yes (restore) | App/package installation |
| Ollama | Yes (restore) | Local LLM inference |
| Claude CLI | Yes (restore) | AI integration |
| `mas` | No | App Store app listing (optional) |

## Prerequisites on New Machine

1. Internet connection
2. GitHub SSH key configured (`ssh-keygen -t ed25519 && ssh-add ~/.ssh/id_ed25519`)
3. macOS (tested on macOS Sonoma+)
4. Apple Silicon (M5 MacBook Air) — scripts use Apple Silicon–specific paths

## File Structure (Portable)

Everything needed to run the backup/restore is in this folder:

```
backup_and_restore/
├── backup.sh              # Run on source Mac
├── restore.sh             # Run on target Mac
├── README.md              # Usage documentation
├── PORTABILITY.md         # This file
├── .gitignore             # Git ignore rules
├── old_scripts/           # Legacy scripts (deprecated)
│   └── README.md          # Legacy script documentation
└── backup_and_restore_query.rtf  # Original requirements (reference only)
```

Generated directories (created at runtime by `backup.sh`):
- `settings/` — macOS preferences, app lists, system state
- `keychain/` — keychain backup
- `models/` — Ollama model list

## Moving to a Different Location

The scripts use the current working directory as their base. Backup output goes to
`./backup_output/` (a subfolder of wherever you run the script). To change the output
location, just `cd` to your desired directory before running.

1. `cd /path/to/your/working/directory`
2. Run `zsh backup.sh` — files go to `./backup_output/`
3. Commit and push: `cd /path/to/backup_and_restore && git add . && git commit -m "backup" && git push`

## Clean Mac Bootstrap

On a brand-new Mac with no tools installed, use the bootstrap script:

```zsh
/usr/bin/env zsh -c "$(curl -fsSL https://raw.githubusercontent.com/IainBate/backup_and_restore/main/bootstrap.sh)"
```

This installs git (via Xcode CLT), clones the repo to `/tmp/backup_and_restore`, and runs restore.

## Security Notes

- The `keychain/` directory is gitignored — never push real keychain data
- API keys in `restore.sh` should be moved to environment variables
- Wi-Fi networks are stored as SSID names only (no passwords)
- Chrome bookmarks are backed up; passwords require Chrome sync
