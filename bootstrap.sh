#!/usr/bin/env bash
set -e

# Cleanup temporary scratch files on exit
cleanup() {
  hdiutil detach /Volumes/Rex -quiet 2>/dev/null || true
  rm -f /tmp/bootstrap-mac-Brewfile /tmp/rex.dmg /tmp/brew-* 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Default configuration flags
DEFAULT_DOTFILES_REPO="dragosmiron/dotfiles-private"
DOTFILES_REPO="${BOOTSTRAP_DOTFILES:-${DOTFILES_REPO:-}}"
RUN_DOTFILES="${BOOTSTRAP_FULL:-}"
CLI_ONLY="${BOOTSTRAP_CLI_ONLY:-false}"
DUMP_BREWFILE="${BOOTSTRAP_DUMP:-}"

if [ -n "$BOOTSTRAP_MINIMAL" ] && [ "$BOOTSTRAP_MINIMAL" != "0" ]; then
  RUN_DOTFILES=false
fi
if [ -n "$DOTFILES_REPO" ]; then
  RUN_DOTFILES=true
fi

# Parse command line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --minimal)
      RUN_DOTFILES=false
      DOTFILES_REPO=""
      shift
      ;;
    --full)
      RUN_DOTFILES=true
      DOTFILES_REPO="${DOTFILES_REPO:-$DEFAULT_DOTFILES_REPO}"
      shift
      ;;
    --dotfiles=*|--repo=*)
      RUN_DOTFILES=true
      DOTFILES_REPO="${1#*=}"
      shift
      ;;
    --dotfiles|--repo)
      RUN_DOTFILES=true
      if [[ -n "${2:-}" ]] && [[ ! "$2" =~ ^- ]]; then
        DOTFILES_REPO="$2"
        shift 2
      else
        DOTFILES_REPO="$DEFAULT_DOTFILES_REPO"
        shift
      fi
      ;;
    --cli-only)
      CLI_ONLY=true
      shift
      ;;
    --dump)
      DUMP_BREWFILE=true
      shift
      ;;
    --no-dump)
      DUMP_BREWFILE=false
      shift
      ;;
    -h|--help)
      echo "Usage: ./bootstrap.sh [OPTIONS]"
      echo ""
      echo "Universal, additive, and idempotent macOS bootstrap script."
      echo ""
      echo "Options:"
      echo "  --minimal               Minimal setup only (installs tools & settings; skips Chezmoi dotfiles)"
      echo "  --full                  Full setup with default personal dotfiles ($DEFAULT_DOTFILES_REPO)"
      echo "  --dotfiles [REPO]       Pull and apply Chezmoi dotfiles from any Git repo (URL or username/repo)"
      echo "  --cli-only              Install CLI runtimes only (skips GUI casks and Rex Terminal)"
      echo "  --dump                  Update/dump ~/.Brewfile with currently installed packages"
      echo "  --no-dump               Skip updating ~/.Brewfile without prompting"
      echo "  -h, --help              Show this help message"
      echo ""
      echo "Examples:"
      echo "  ./bootstrap.sh --minimal"
      echo "  ./bootstrap.sh --full"
      echo "  ./bootstrap.sh --dotfiles username/dotfiles"
      echo "  ./bootstrap.sh --dotfiles https://github.com/myorg/work-dotfiles.git"
      echo "  ./bootstrap.sh --cli-only --minimal"
      echo "  ./bootstrap.sh --minimal --dump"
      echo ""
      echo "Environment variables:"
      echo "  BOOTSTRAP_MINIMAL=1              Equivalent to --minimal"
      echo "  BOOTSTRAP_FULL=1                 Equivalent to --full"
      echo "  BOOTSTRAP_DOTFILES=\"user/repo\"   Equivalent to --dotfiles user/repo"
      echo "  BOOTSTRAP_CLI_ONLY=1             Equivalent to --cli-only"
      echo "  BOOTSTRAP_DUMP=1                 Equivalent to --dump"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run with --help for usage."
      exit 1
      ;;
  esac
done

echo "🚀 Starting automated Mac bootstrap..."

# 1. Xcode Command Line Tools
if ! xcode-select -p >/dev/null 2>&1; then
  echo "📦 Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "Please complete the prompt and re-run this script."
  exit 1
fi

# 2. Homebrew
if ! command -v brew >/dev/null 2>&1; then
  if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    echo "🍺 Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -x "/opt/homebrew/bin/brew" ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x "/usr/local/bin/brew" ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
fi

# 3. Locate baseline Brewfile
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
fi
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/Brewfile" ]; then
  BREWFILE="$SCRIPT_DIR/Brewfile"
else
  BREWFILE="/tmp/bootstrap-mac-Brewfile"
  echo "📥 Fetching baseline Brewfile from repository..."
  curl -fsSL -o "$BREWFILE" "https://raw.githubusercontent.com/dragosmiron/bootstrap-mac/main/Brewfile"
fi

# 4. Install Baseline Packages & Tools (Additive only)
if [ "$CLI_ONLY" = true ]; then
  echo "📦 Installing baseline CLI tools from Brewfile (--cli-only mode)..."
  grep -v '^cask ' "$BREWFILE" | brew bundle --file=- --no-upgrade || grep -v '^cask ' "$BREWFILE" | brew bundle --file=- || true
else
  echo "📦 Installing baseline packages and applications from Brewfile (adopting existing apps)..."
  brew bundle --file="$BREWFILE" --no-upgrade || brew bundle --file="$BREWFILE" || {
    echo "⚠️  Note: Some Brewfile packages or casks may require manual intervention or password prompt."
  }
fi

# Optional dump/update of ~/.Brewfile with all currently installed packages
if [ -z "$DUMP_BREWFILE" ]; then
  TMP_CANDIDATE="/tmp/brew-candidate-$$.txt"
  brew bundle dump --force --file="$TMP_CANDIDATE" 2>/dev/null || true
  if [ -f "$TMP_CANDIDATE" ]; then
    if ! grep -q "cask_args.*adopt:" "$TMP_CANDIDATE" 2>/dev/null; then
      TMP_CANDIDATE_FMT="/tmp/brew-candidate-fmt-$$.txt"
      echo 'cask_args appdir: "/Applications", adopt: true' > "$TMP_CANDIDATE_FMT"
      echo "" >> "$TMP_CANDIDATE_FMT"
      cat "$TMP_CANDIDATE" >> "$TMP_CANDIDATE_FMT"
      mv "$TMP_CANDIDATE_FMT" "$TMP_CANDIDATE"
    fi

    # Check if ~/.Brewfile is already identical
    if [ -f "$HOME/.Brewfile" ] && git diff --no-index --quiet "$HOME/.Brewfile" "$TMP_CANDIDATE"; then
      echo "✨ ~/.Brewfile is already up to date with all installed packages."
      DUMP_BREWFILE=false
      rm -f "$TMP_CANDIDATE" 2>/dev/null || true
    elif [ -t 0 ] || [ -c /dev/tty ]; then
      while true; do
        echo ""
        if ! read -r -p "📋 Changes detected. Would you like to update/dump ~/.Brewfile with all currently installed packages? [y/N/d]: " REPLY_DUMP </dev/tty; then
          echo ""
          rm -f "$TMP_CANDIDATE" 2>/dev/null || true
          exit 130
        fi
        case "$REPLY_DUMP" in
          [dD])
            echo ""
            echo "🔍 Generating diff of installed packages vs ~/.Brewfile..."
            if [ -f "$HOME/.Brewfile" ]; then
              git diff --no-index --color "$HOME/.Brewfile" "$TMP_CANDIDATE" || true
            else
              echo "📄 No existing ~/.Brewfile found on disk. New file will contain:"
              cat "$TMP_CANDIDATE"
            fi
            ;;
          [yY][eE][sS]|[yY])
            echo "📋 Updating ~/.Brewfile to reflect current machine state..."
            if [ -f "$HOME/.Brewfile" ]; then
              cp "$HOME/.Brewfile" "$HOME/.Brewfile.bak" 2>/dev/null || true
            fi
            mv "$TMP_CANDIDATE" "$HOME/.Brewfile"
            echo "✅ ~/.Brewfile updated (backup saved to ~/.Brewfile.bak)."
            DUMP_BREWFILE=false
            break
            ;;
          *)
            DUMP_BREWFILE=false
            break
            ;;
        esac
      done
      rm -f "$TMP_CANDIDATE" 2>/dev/null || true
    else
      DUMP_BREWFILE=false
      rm -f "$TMP_CANDIDATE" 2>/dev/null || true
    fi
  fi
fi

if [ "$DUMP_BREWFILE" = true ]; then
  echo "📋 Updating ~/.Brewfile to reflect current machine state..."
  if [ -f "$HOME/.Brewfile" ]; then
    cp "$HOME/.Brewfile" "$HOME/.Brewfile.bak" 2>/dev/null || true
  fi
  brew bundle dump --force --file="$HOME/.Brewfile"
  if ! grep -q "cask_args.*adopt:" "$HOME/.Brewfile" 2>/dev/null; then
    TMP_DUMP="$(mktemp)"
    echo 'cask_args appdir: "/Applications", adopt: true' > "$TMP_DUMP"
    echo "" >> "$TMP_DUMP"
    cat "$HOME/.Brewfile" >> "$TMP_DUMP"
    mv "$TMP_DUMP" "$HOME/.Brewfile"
  fi
  echo "✅ ~/.Brewfile updated (backup saved to ~/.Brewfile.bak)."
fi

# 5. Shell Ergonomics in ~/.zshrc (Guarded marked block, never overwrites existing config)
if ! grep -q "# >>> bootstrap-mac >>>" "$HOME/.zshrc" 2>/dev/null; then
  echo "🐚 Adding modern shell ergonomics block to ~/.zshrc..."
  cat <<'EOF' >> "$HOME/.zshrc"

# >>> bootstrap-mac >>>
# --- Modern Shell Power Tools (Guarded) ---
# 0. Ensure Homebrew environment is initialized (essential for non-login interactive shells)
if ! command -v brew >/dev/null 2>&1; then
  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# 1. User local binary path (e.g. Rex CLI, user scripts)
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

# 2. Zoxide: smart directory jumping (e.g. `z proj`)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# 3. FZF: interactive fuzzy history (Ctrl+R) and file picker (Ctrl+T)
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

# 4. Modern CLI aliases (safe, plain output)
if command -v bat >/dev/null 2>&1; then
  alias cat="bat --plain --paging=never"
fi

if command -v eza >/dev/null 2>&1; then
  alias ls="eza --icons --group-directories-first"
  alias ll="eza -la --icons --git --group-directories-first"
  alias tree="eza --tree --icons"
fi

if command -v lazygit >/dev/null 2>&1; then
  alias lg="lazygit"
fi

# 5. Guarded auto-suggestions and syntax highlighting (syntax-highlighting must load last)
_BREW_PREFIX="${HOMEBREW_PREFIX:-/opt/homebrew}"
if [[ -r "$_BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$_BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
if [[ -r "$_BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "$_BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
unset _BREW_PREFIX
# <<< bootstrap-mac <<<
EOF
else
  echo "🐚 Modern shell ergonomics already present in ~/.zshrc."
fi

# 6. Install Rex Terminal (Direct Preview DMG, skipped if --cli-only)
if [ "$CLI_ONLY" != true ]; then
  if [ ! -d "/Applications/Rex Beta.app" ]; then
    echo "📥 Installing Rex Terminal..."
    curl -fsSL -o /tmp/rex.dmg "https://blob.superlogical.com/download/rex-app/preview/latest.dmg"
    hdiutil detach /Volumes/Rex -quiet 2>/dev/null || true
    hdiutil attach /tmp/rex.dmg -mountpoint /Volumes/Rex -nobrowse -quiet
    cp -R "/Volumes/Rex/Rex Beta.app" /Applications/
    hdiutil detach /Volumes/Rex -quiet 2>/dev/null || true
    rm -f /tmp/rex.dmg
  fi

  if [ -d "/Applications/Rex Beta.app" ]; then
    mkdir -p "$HOME/.local/bin"
    ln -sf "/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex" "$HOME/.local/bin/rex"
  fi
fi

# 7. macOS System Preferences
echo "🍎 Applying macOS system preferences..."
mkdir -p "$HOME/Desktop/Screenshots"
defaults write com.apple.screencapture location "$HOME/Desktop/Screenshots"
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write -g ApplePressAndHoldEnabled -bool false
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

# 8. Optional Personal Dotfiles via Chezmoi
if [ -z "$RUN_DOTFILES" ]; then
  if [ -t 0 ] || [ -c /dev/tty ]; then
    echo ""
    echo "🔐 Optional Chezmoi Dotfiles Sync:"
    if ! read -r -p "Would you like to apply a Chezmoi dotfiles repository? [y/N]: " REPLY </dev/tty; then
      echo ""
      exit 130
    fi
    case "$REPLY" in
      [yY][eE][sS]|[yY])
        RUN_DOTFILES=true
        if ! read -r -p "Enter Git repo (e.g. username/repo or full URL) [default: $DEFAULT_DOTFILES_REPO]: " USER_REPO </dev/tty; then
          echo ""
          exit 130
        fi
        DOTFILES_REPO="${USER_REPO:-$DEFAULT_DOTFILES_REPO}"
        ;;
      *)
        RUN_DOTFILES=false
        ;;
    esac
  else
    RUN_DOTFILES=false
  fi
fi

if [ "$RUN_DOTFILES" = true ]; then
  DOTFILES_REPO="${DOTFILES_REPO:-$DEFAULT_DOTFILES_REPO}"
  echo "⚙️  Preparing Chezmoi for dotfiles repo: $DOTFILES_REPO..."
  if ! command -v chezmoi >/dev/null 2>&1; then
    brew install chezmoi
  fi

  # Normalize repository URL for reachability test
  TEST_URL="$DOTFILES_REPO"
  if [[ "$TEST_URL" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    TEST_URL="https://github.com/$TEST_URL.git"
  fi

  # Determine if repository is public or requires authentication
  if [[ "$DOTFILES_REPO" =~ ^git@ ]]; then
    # Explicit SSH URL (e.g. git@github.com:owner/repo.git)
    HOST="${DOTFILES_REPO#*@}"
    HOST="${HOST%%:*}"
    if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T "git@$HOST" 2>&1 | grep -qE "successfully authenticated|Hi "; then
      echo "🔑 SSH key not detected for $HOST. Please ensure your SSH agent or key is loaded."
    fi
  elif GIT_TERMINAL_PROMPT=0 git ls-remote "$TEST_URL" HEAD >/dev/null 2>&1; then
    echo "🔓 Public repository accessible without credentials."
  else
    echo "🔒 Private repository detected. Setting up GitHub authentication..."
    if ! command -v gh >/dev/null 2>&1; then
      brew install gh
    fi
    if ! gh auth status >/dev/null 2>&1; then
      echo "🌐 Authenticating with GitHub to access $DOTFILES_REPO..."
      gh auth login -p https -w
    fi
    gh auth setup-git
    DOTFILES_REPO="$TEST_URL"
  fi

  if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
    echo "📥 Pulling latest dotfile changes via Chezmoi..."
    chezmoi update
  else
    echo "📥 Initializing and applying dotfiles from $DOTFILES_REPO via Chezmoi..."
    chezmoi init --apply "$DOTFILES_REPO"
  fi
else
  echo "⏭️  Skipping Chezmoi dotfiles sync (minimal bootstrap complete)."
fi

# Ensure git global ignore is configured if present
if [ -f "$HOME/.gitignore_global" ]; then
  git config --global core.excludesfile "~/.gitignore_global"
fi

echo "✅ Mac bootstrap completed successfully!"
