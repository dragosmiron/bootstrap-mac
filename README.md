# Mac Bootstrap (`bootstrap-mac`)

Automated, idempotent, and non-destructive macOS bootstrapping and baseline provisioning.

## Overview

This repository provides a single-command setup for **brand-new Macs** as well as **existing or secondary machines**. It is designed to be **purely additive**:

- **Non-Destructive**: Never overwrites your existing `~/.zshrc` or personalized configs; only appends guarded power tools if missing.
- **Additive Software Installation**: Uses `Brewfile` with `adopt: true` so it only installs missing tools and never deletes or replaces existing applications.
- **Decoupled Dotfiles**: Baseline bootstrap installs core tools and system settings independently; personal dotfiles (`dotfiles-private` via Chezmoi) are an optional overlay.

---

## Quickstart

### 1. Interactive Setup (Universal One-Liner)

Run directly in Terminal:

```bash
/usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/dragosmiron/bootstrap-mac/main/bootstrap.sh)"
```

During execution, it will install the baseline environment and prompt whether you want to also pull and apply your private Chezmoi dotfiles (`[y/N]`).

---

### 2. Execution Modes & Command Flags

You can control exactly how much or how little is applied:

| Command | Behavior |
| :--- | :--- |
| `./bootstrap.sh` | **Interactive**: Installs baseline stack and asks before applying personal Chezmoi dotfiles. |
| `./bootstrap.sh --baseline` | **Additive Baseline Only**: Installs tools, shell ergonomics, and defaults; completely skips personal dotfiles. |
| `./bootstrap.sh --full` | **Full Machine Provisioning**: Installs baseline stack AND pulls/applies private Chezmoi dotfiles. |
| `./bootstrap.sh --cli-only` | **Headless / Server Mode**: Installs only CLI runtimes and tools; skips all GUI casks and Rex Terminal. |

#### Environment Variables for Automation:
```bash
# Automated full setup on a new machine:
BOOTSTRAP_FULL=1 /usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/dragosmiron/bootstrap-mac/main/bootstrap.sh)"

# Automated baseline-only setup (safe on work or existing Macs):
BOOTSTRAP_FULL=0 /usr/bin/env bash -c "$(curl -fsSL https://raw.githubusercontent.com/dragosmiron/bootstrap-mac/main/bootstrap.sh)"
```

---

## What `bootstrap.sh` Does Automatically

1. **Xcode Command Line Tools**: Checks and prompts for installation if missing.
2. **Homebrew**: Installs Homebrew non-interactively if missing and configures `$PATH`.
3. **Baseline Software (`Brewfile`)**: Installs CLI developer tools and GUI casks (uses local `Brewfile` if cloned, or fetches the baseline manifest via raw GitHub).
4. **Shell Ergonomics (`~/.zshrc`)**: Appends a clearly marked `# >>> bootstrap-mac >>>` block with Zoxide, FZF, and modern aliases. If the block already exists, it is untouched.
5. **Rex Terminal**: Installs Rex Beta and creates the CLI symlink at `~/.local/bin/rex` (skipped if `--cli-only`).
6. **macOS System Defaults**: Sets screenshot routing, fast key repeats, Finder pathbar, and `.DS_Store` suppression.
7. **Optional Personal Chezmoi Dotfiles**: If selected, installs `chezmoi` and `gh`, establishes authentication, and syncs `dragosmiron/dotfiles-private`.

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
