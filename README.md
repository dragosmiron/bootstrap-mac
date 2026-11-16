# Mac Bootstrap (`bootstrap-mac`)

Automated, idempotent macOS machine bootstrapping and environment provisioning.

## Overview

This repository provides a single-command bootstrap for a fresh or existing Mac setup, managing tools, configurations, and system preferences across:

- **Xcode Command Line Tools**: Base developer toolchain.
- **Homebrew**: Package management for CLI tools, runtimes, and GUI applications (`~/.Brewfile`).
- **Chezmoi**: Private dotfiles management syncing `.zshrc`, `.gitignore_global`, and `.Brewfile` from `dragosmiron/dotfiles-private`.
- **Rex Terminal**: Direct automated DMG installation & CLI symlinking (`~/.local/bin/rex`).
- **macOS System Defaults**: Fast key repeating, dedicated screenshot routing, pathbars, and `.DS_Store` suppression.

---

## Quickstart on a Brand New Mac

To provision a fresh Mac from scratch, paste this single command into Terminal:

```bash
/usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/dragosmiron/bootstrap-mac/main/bootstrap.sh)"
```

### What happens automatically:

1. **Xcode Command Line Tools**: Detected or installed automatically.
2. **Homebrew**: Installs Homebrew if missing and configures `$PATH`.
3. **Chezmoi & GitHub CLI**: Installs both via Homebrew.
4. **GitHub Authentication**: Checks if SSH keys or `gh` auth are present. If you're on a blank Mac, it runs `gh auth login -p https -w` to log you into GitHub via browser in 1 click, then configures `git` credentials.
5. **Private Dotfiles**: Clones and applies `dragosmiron/dotfiles-private` via Chezmoi, laying down your `~/.Brewfile`, `~/.zshrc`, and `~/.gitignore_global`.
6. **Applications & Runtimes**: Runs `brew bundle` with `--adopt` to install all developer CLI tools, packages, and GUI casks without conflicts.
7. **Rex Terminal**: Downloads the latest Rex Beta DMG and symlinks the CLI to `~/.local/bin/rex`.
8. **System Preferences**: Applies all Finder, keyboard, and screenshot defaults.

---

## Provisioned Stack

### CLI Runtimes & Developer Tools
- **Runtimes:** `node`, `go`, `python@3.12`
- **Productivity & Search:** `fzf`, `zoxide`, `bat`, `eza`, `lazygit`, `gh`, `chezmoi`
- **Shell:** Zsh with `zsh-autosuggestions` and `zsh-syntax-highlighting`

### GUI Applications (Homebrew Casks)
- **Essentials & Windows:** Raycast, AltTab, KeepingYouAwake
- **Security & Privacy:** Bitwarden, Little Snitch, NordVPN, NetBird, AdGuard
- **Productivity & Notes:** Obsidian, Google Chrome, Zed
- **Virtualization:** OrbStack
- **Utilities & Media:** Keka, Pearcleaner, VLC, Calibre, Stremio

### Non-Homebrew Applications
- **Rex Terminal Beta**: Installed from direct preview DMG and symlinked to `~/.local/bin/rex`.

---

## System Defaults Applied

1. **Screenshots:** Routed to dedicated `~/Desktop/Screenshots/`.
2. **Finder:**
   - Always display file extensions.
   - Show bottom breadcrumb pathbar.
   - Suppress creation of `.DS_Store` files on network and USB volumes.
3. **Keyboard:** Disabled press-and-hold accent popup to enable rapid key repeat in terminal and editors.
4. **Git Hygiene:** Global excludes registered from `~/.gitignore_global`.

---

## Verification

To verify the installation on an active machine:

```bash
# 1. Check CLI runtimes & tools
which fzf zoxide bat eza lazygit node go python3.12 rex

# 2. Verify Homebrew bundle state
brew bundle check --no-upgrade --file="$HOME/.Brewfile"

# 3. Test shell syntax
zsh -n ~/.zshrc

# 4. Check Chezmoi dotfiles tracking
chezmoi managed
```
