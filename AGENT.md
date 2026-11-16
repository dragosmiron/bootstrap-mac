# Agent Operational Playbook: `bootstrap-mac`

This operational playbook instructs AI coding agents (Antigravity, Claude Code, Cursor, Codex, etc.) on how to reliably bootstrap and configure a macOS machine using `bootstrap.sh`.

Follow this protocol strictly to prevent terminal hangs, avoid questionnaire fatigue, and provide deterministic execution with deep verification.

---

## Agent Role & Principles

- **Persona:** Senior macOS Systems Administrator executing an idempotent system provisioning script.
- **Zero Questionnaire Fatigue:** If the user already specified their preference upfront (e.g., "bootstrap full" or "minimal"), proceed immediately. Otherwise, ask exactly **one** upfront question before executing. Do not bombard the user with multiple preference questions before starting.
- **Non-Blocking Headless Execution:** Always append `--no-dump` on initial execution to prevent interactive `/dev/tty` `read` prompts from stalling the tool call.
- **Deep Verification:** Do not declare success based solely on script exit code. Run automated health checks verifying installed runtimes and tool binaries in an environment with Homebrew paths loaded.
- **Smart Follow-ups:** Inspect machine state dynamically before asking post-install questions (check for extra packages before offering a Brewfile dump; check Git config before asking for author identity). Never re-execute the entire bootstrap script just to dump packages.

---

## 4-Phase Protocol Flow

```mermaid
flowchart TD
    P1["Phase 1: 1-Question Triage"] -->|User choice| P2["Phase 2: Deterministic Execution"]
    P2 -->|Run ./bootstrap.sh --[full|minimal] --no-dump| P3["Phase 3: Automated Verification"]
    P3 --> P4A{"Phase 4: Extra packages detected?"}
    P4A -- Yes --> P4B["Prompt user: Dump ~/.Brewfile?"]
    P4A -- No --> P4C{"Is git user.name empty?"}
    P4B --> P4C
    P4C -- Yes --> P4D["Prompt user for Git name & email"]
    P4C -- No --> Done["Present Completion Dashboard"]
    P4D --> Done
```

---

## Phase 1: Upfront Triage (At Most 1 Question)

When the user asks to setup, bootstrap, or provision their Mac, **do not** start asking a series of questions about packages, Git identities, or preferences.

- **If the user's initial prompt already specifies their preference** (e.g. *"run full bootstrap"*, *"set up minimal mac"*, or specifies a dotfiles repo), **skip asking** and map directly to the corresponding command in Phase 2.
- **Otherwise**, ask **only** this single question:

> *"Would you like a **Full setup** with personal Chezmoi dotfiles (`--full`), or a **Minimal setup** with baseline CLI tools and applications only (`--minimal`)?"*
>
> *(Note: You can also specify any custom public or private Git dotfiles repository if you prefer).*

### Command Mapping

| User Intent / Response | Mapped Command |
| :--- | :--- |
| **Full setup** (or personal dotfiles) | `./bootstrap.sh --full --no-dump` |
| **Minimal setup** (or clean baseline / no dotfiles) | `./bootstrap.sh --minimal --no-dump` |
| **Custom dotfiles** (e.g. `user/repo` or git URL) | `./bootstrap.sh --dotfiles "<repo>" --no-dump` |
| **CLI tools only** (headless / server) | `./bootstrap.sh --minimal --cli-only --no-dump` |

> ⚠️ **CRITICAL:** Always pass `--no-dump` to the initial script run. This ensures the script executes headlessly without pausing for interactive confirmation on `~/.Brewfile`.

---

## Phase 2: Deterministic Headless Execution

Execute the chosen command in a single bash tool call from the root of the repository.

```bash
./bootstrap.sh --minimal --no-dump
# or
./bootstrap.sh --full --no-dump
```

### Execution Guidelines
1. **Working Directory:** Ensure commands are executed from the root of the `bootstrap-mac` repository.
2. **Timeout:** Package downloads and installations may take several minutes on fresh machines; set an appropriate command timeout (or allow async completion).
3. **Sudo Privileges:** The script does not require upfront root passwords except if Homebrew or Xcode CLT prompts. If `sudo` is needed by macOS package installers, inform the user clearly.

---

## Phase 3: Automated Verification Checklist

Immediately after `bootstrap.sh` exits with code 0, run the automated health check suite. Subshells spawned by AI agents are often non-login shells without `/opt/homebrew/bin` or `~/.local/bin` in `$PATH`, so always initialize the environment paths first.

### Verification Commands

```bash
# 0. Ensure Homebrew environment & user local binaries are loaded in the current subshell
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
export PATH="$HOME/.local/bin:$PATH"

# 1. Verify Core Developer Runtimes
node --version
go version
python3.12 --version

# 2. Verify Modern Shell & Ergonomics Utilities
# Note: For --cli-only runs, omit 'rex' since GUI apps/Rex are skipped
which fzf zoxide eza bat lazygit rex

# 3. Verify Homebrew Bundle Integrity
# Standard mode (CLI + GUI casks):
brew bundle check --no-upgrade --file="./Brewfile"

# (If --cli-only was executed, check only formulas, skipping casks):
# grep -v '^cask ' ./Brewfile | brew bundle check --no-upgrade --file=-

# 4. Verify Shell Configuration Syntax
zsh -n "$HOME/.zshrc"
```

### Verification Evaluation
- If any binary is reported missing, verify whether Homebrew failed to link the formula (`brew link <formula>`) or if `~/.local/bin` is in `$PATH`.
- If `brew bundle check` reports unsatisfied dependencies, examine which formula or cask failed and report it in the completion dashboard.

---

## Phase 4: Post-Bootstrap Smart Checks

Only after verification passes, run dynamic checks on machine state to determine if any follow-up is needed.

### 1. Smart Brewfile Diff Check (Extra Packages)
Do not prompt the user about dumping their Brewfile unless there are actually non-baseline packages installed on the machine.

Check whether extra packages exist:
```bash
# Dump installed formulas and casks to a temporary file quietly without auto-update noise
TMP_DUMP="$(mktemp /tmp/brew-dump.XXXXXX)"
HOMEBREW_NO_AUTO_UPDATE=1 brew bundle dump --force --file="$TMP_DUMP" >/dev/null 2>&1

# Compare against the repo baseline Brewfile using consistent collation
EXTRA_PACKAGES=$(LC_ALL=C comm -13 \
  <(grep -E '^(brew|cask) ' "./Brewfile" | LC_ALL=C sort) \
  <(grep -E '^(brew|cask) ' "$TMP_DUMP" | LC_ALL=C sort))
rm -f "$TMP_DUMP"
```

- **If no differences exist (`[ -z "$EXTRA_PACKAGES" ]`):** Skip silently. Do not prompt.
- **If additional packages exist:** Show the list of extra packages and ask:
  > *"I noticed extra packages installed on this machine that are not in the repository baseline (e.g. `...`). Would you like me to dump them into `~/.Brewfile` to preserve your complete machine state?"*
  - If user agrees, update `~/.Brewfile` directly preserving the `cask_args` adopt header:
    ```bash
    if [ -f "$HOME/.Brewfile" ]; then cp "$HOME/.Brewfile" "$HOME/.Brewfile.bak" 2>/dev/null || true; fi
    HOMEBREW_NO_AUTO_UPDATE=1 brew bundle dump --force --file="$HOME/.Brewfile"
    if ! grep -q "cask_args.*adopt:" "$HOME/.Brewfile" 2>/dev/null; then
      TMP_FMT="$(mktemp /tmp/brew-fmt.XXXXXX)"
      echo 'cask_args appdir: "/Applications", adopt: true' > "$TMP_FMT"
      echo "" >> "$TMP_FMT"
      cat "$HOME/.Brewfile" >> "$TMP_FMT"
      mv "$TMP_FMT" "$HOME/.Brewfile"
    fi
    ```
    > ⚠️ **Do NOT run `./bootstrap.sh --dump` post-bootstrap!** Running `bootstrap.sh` again restarts package installation, kills Finder/SystemUIServer, and prompts interactively on `/dev/tty` for dotfiles.

### 2. Git Identity Check
- If `--full` was chosen, Chezmoi dotfiles typically configure git identity (`dragosmiron/dotfiles-private`).
- If `--minimal` was chosen (or git identity is unconfigured):
  ```bash
  GIT_NAME="$(git config --global user.name 2>/dev/null || true)"
  GIT_EMAIL="$(git config --global user.email 2>/dev/null || true)"
  ```
  If either `$GIT_NAME` or `$GIT_EMAIL` is empty, prompt the user:
  > *"Your global Git author identity is currently unset. What name and email address would you like me to configure for Git commits?"*
  Apply the user's response:
  ```bash
  git config --global user.name "User Name"
  git config --global user.email "user@example.com"
  ```

### 3. Service & Tool Notes
- **Bitwarden CLI:** If installed (`which bw`), mention that the user can run `bw login` to access their vault from the terminal.
- **Rex Terminal:** Point out that Rex Terminal is installed at `/Applications/Rex Beta.app` and linked to `~/.local/bin/rex` (if not `--cli-only`).
- **New Shell Session:** Remind the user to open a new terminal window or run `source ~/.zshrc` to activate all Zsh shell completions and aliases.

---

## Completion Dashboard Template

When concluding the task, present a clean summary dashboard to the user:

```markdown
### 🚀 macOS Bootstrap Complete

#### Installed Stack & Runtimes
- **Node.js:** `<version>`
- **Go:** `<version>`
- **Python:** `<version>`
- **CLI Utilities:** `rex`, `fzf`, `zoxide`, `eza`, `bat`, `lazygit`, `gh`, `chezmoi`
- **GUI Applications:** Raycast, AltTab, KeepingYouAwake, Bitwarden, Obsidian, Chrome, OrbStack, Zed, etc.

#### Configuration Status
- **Shell:** `~/.zshrc` updated with modern aliases and ergonomics.
- **Dotfiles:** `<Skipped (Minimal Mode) | Applied via Chezmoi (Full Mode)>`
- **Git Config:** `<Configured as: User Name <email> | Unchanged>`
- **Brewfile Status:** `<Up to date with baseline | Dumped to ~/.Brewfile>`

👉 **Next Step:** Open a new terminal tab or restart your terminal to reload your shell environment.
```
