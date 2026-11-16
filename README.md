# Mac Bootstrap (`bootstrap-mac`)

Automated, idempotent, and non-destructive macOS bootstrapping and baseline provisioning.

## Overview

This repository provides a single-command setup for **brand-new Macs** as well as **existing, secondary, or work machines**. It is designed to be **purely additive and repository-independent**:

- **Minimal & Independent**: Runs a complete baseline environment with **zero dotfiles repository** required.
- **Any Dotfiles Repository**: Bring your own Chezmoi repo (public or private, personal or work) or use none at all.
- **Non-Destructive**: Never overwrites your existing `~/.zshrc` or personalized configs; only appends guarded power tools if missing.
- **Additive Software Installation**: Uses `Brewfile` with `adopt: true` so it only installs missing tools and never deletes or replaces existing applications.

---

## Quickstart

### 1. Interactive Setup (Universal One-Liner)

Run directly in Terminal:

```bash
/usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/dragosmiron/bootstrap-mac/main/bootstrap.sh)"
```

During execution, it installs the baseline environment and prompts whether you want to apply a Chezmoi dotfiles repository (`[y/N]`) and allows specifying any repo URL.

---

### 2. Execution Modes & Command Flags

You can control exactly how much or how little is applied:

| Command | Behavior |
| :--- | :--- |
| `./bootstrap.sh --baseline` | **Minimal Setup Only**: Installs core tools, shell ergonomics, and defaults; requires **no dotfiles repo and no GitHub login**. |
| `./bootstrap.sh --dotfiles <repo>` | **Custom Dotfiles Sync**: Applies baseline stack and pulls Chezmoi dotfiles from **any** repo (e.g. `username/repo` or full URL, public or private). |
| `./bootstrap.sh --full` | **Default Personal Setup**: Applies baseline stack and syncs default personal repo (`dragosmiron/dotfiles-private`). |
| `./bootstrap.sh --cli-only` | **Headless / Server Mode**: Installs only CLI runtimes and tools; skips all GUI casks and Rex Terminal. |

#### One-Liner Automation Examples:

```bash
# Minimal baseline only (no dotfiles repo, zero auth required):
/usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/dragosmiron/bootstrap-mac/main/bootstrap.sh)" -- --baseline

# Setup with any custom public or work dotfiles repo:
/usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/dragosmiron/bootstrap-mac/main/bootstrap.sh)" -- --dotfiles mycompany/mac-dotfiles

# Full personal setup:
/usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/dragosmiron/bootstrap-mac/main/bootstrap.sh)" -- --full
```

---

## What `bootstrap.sh` Does Automatically

1. **Xcode Command Line Tools**: Checks and prompts for installation if missing.
2. **Homebrew**: Installs Homebrew non-interactively if missing and configures `$PATH`.
3. **Baseline Software (`Brewfile`)**: Installs CLI developer tools and GUI casks (uses local `Brewfile` if cloned, or fetches the baseline manifest via raw GitHub).
4. **Shell Ergonomics (`~/.zshrc`)**: Appends a clearly marked `# >>> bootstrap-mac >>>` block with Zoxide, FZF, and modern aliases. If the block already exists, it is untouched.
5. **Rex Terminal**: Installs Rex Beta and creates the CLI symlink at `~/.local/bin/rex` (skipped if `--cli-only`).
6. **macOS System Defaults**: Sets screenshot routing, fast key repeats, Finder pathbar, and `.DS_Store` suppression.
7. **Optional Chezmoi Dotfiles**: If specified, verifies if the repo is public (clones immediately) or private (prompts 1-click GitHub CLI login), then applies dotfiles via Chezmoi.

---

## Baseline Stack Included

### CLI Runtimes & Developer Tools
- **Runtimes:** `node`, `go`, `python@3.12`
- **Productivity & Search:** `fzf`, `zoxide`, `bat`, `eza`, `lazygit`, `gh`, `chezmoi`, `bitwarden-cli`
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

## Verification

To verify the installation on an active machine:

```bash
# Check CLI runtimes & tools
which fzf zoxide bat eza lazygit node go python3.12 rex

# Verify Homebrew bundle state
brew bundle check --no-upgrade --file="./Brewfile"

# Test shell syntax
zsh -n ~/.zshrc
```
