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

## Quickstart

### On a Fresh Mac

Clone and run the bootstrap script:

```bash
git clone git@github.com:dragosmiron/bootstrap-mac.git ~/Projects/bootstrap-mac
cd ~/Projects/bootstrap-mac
./bootstrap.sh
```

Or run directly via curl if SSH keys are already configured:

```bash
/usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/dragosmiron/bootstrap-mac/main/bootstrap.sh)"
```

---

## Provisioned Stack

### CLI Runtimes & Developer Tools
- **Runtimes:** `node`, `go`, `python@3.12`
- **Productivity & Search:** `fzf`, `zoxide`, `bat`, `eza`, `lazygit`, `gh`, `chezmoi`, `mas`
- **Shell:** Zsh with `zsh-autosuggestions` and `zsh-syntax-highlighting`

### GUI Applications (Homebrew Casks)
- **Essentials & Windows:** Raycast, AltTab
- **Security & Privacy:** Bitwarden, Little Snitch, NordVPN, NetBird, AdGuard
- **Productivity & Notes:** Obsidian, Google Chrome, Zed
- **Virtualization:** OrbStack
- **Utilities & Media:** Keka, Pearcleaner, VLC, Calibre, Stremio

### Mac App Store (via `mas`)
- PDFgear (`6469021132`)

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
