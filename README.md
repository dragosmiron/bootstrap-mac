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

Because `bootstrap-mac` and `dotfiles-private` are **private** repositories, a brand-new Mac needs two things to begin: **Homebrew** and **GitHub authentication**.

Run these 3 commands in your terminal:

```bash
# 1. Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"

# 2. Install GitHub CLI & Log in (browser-based 1-click login)
brew install gh
gh auth login -p https -w

# 3. Clone and run the bootstrap script
gh repo clone dragosmiron/bootstrap-mac ~/Projects/bootstrap-mac
~/Projects/bootstrap-mac/bootstrap.sh
```

---

### What `bootstrap.sh` does automatically

Once started, `bootstrap.sh` handles everything end-to-end:
1. Verifies/installs Xcode Command Line Tools.
2. Ensures Homebrew is present and on `$PATH`.
3. Installs `chezmoi` and `gh`, configuring `gh auth setup-git` (supporting either SSH keys or HTTPS token auth).
4. Pulls your private dotfiles (`dragosmiron/dotfiles-private`) and deposits `~/.Brewfile`, `~/.zshrc`, and `~/.gitignore_global`.
5. Runs `brew bundle` with `--adopt` to install all CLI runtimes, security tools, and GUI apps (adopting pre-existing apps in `/Applications` without errors).
6. Installs and configures Rex Terminal Beta (`~/.local/bin/rex`).
7. Applies all macOS system preferences (screenshots directory, fast key repeats, pathbar, `.DS_Store` suppression).

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
