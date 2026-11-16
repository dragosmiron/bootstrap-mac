#!/usr/bin/env bash
set -e

# Default configuration flags
DEFAULT_DOTFILES_REPO="dragosmiron/dotfiles-private"
DOTFILES_REPO="${BOOTSTRAP_DOTFILES:-${DOTFILES_REPO:-}}"
RUN_DOTFILES="${BOOTSTRAP_FULL:-}"
CLI_ONLY="${BOOTSTRAP_CLI_ONLY:-false}"
DUMP_BREWFILE="${BOOTSTRAP_DUMP:-}"

if [ -n "$BOOTSTRAP_BASELINE" ] && [ "$BOOTSTRAP_BASELINE" != "0" ]; then
  RUN_DOTFILES=false
fi
if [ -n "$DOTFILES_REPO" ]; then
  RUN_DOTFILES=true
fi

# Parse command line options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --baseline|--minimal)
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
      echo "  --baseline, --minimal   Minimal setup only (installs tools & settings; skips Chezmoi dotfiles)"
      echo "  --full                  Full setup with default personal dotfiles ($DEFAULT_DOTFILES_REPO)"
      echo "  --dotfiles [REPO]       Pull and apply Chezmoi dotfiles from any Git repo (URL or username/repo)"
      echo "  --cli-only              Install CLI runtimes only (skips GUI casks and Rex Terminal)"
      echo "  --dump                  Update/dump ~/.Brewfile with currently installed packages"
      echo "  --no-dump               Skip updating ~/.Brewfile without prompting"
      echo "  -h, --help              Show this help message"
      echo ""
      echo "Examples:"
      echo "  ./bootstrap.sh --baseline"
      echo "  ./bootstrap.sh --full"
      echo "  ./bootstrap.sh --dotfiles username/dotfiles"
      echo "  ./bootstrap.sh --dotfiles https://github.com/myorg/work-dotfiles.git"
      echo "  ./bootstrap.sh --cli-only --baseline"
      echo "  ./bootstrap.sh --baseline --dump"
      echo ""
      echo "Environment variables:"
      echo "  BOOTSTRAP_BASELINE=1             Equivalent to --baseline"
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/Brewfile" ]; then
  BREWFILE="$SCRIPT_DIR/Brewfile"
elif [ -f "$HOME/.Brewfile" ]; then
  BREWFILE="$HOME/.Brewfile"
else
  BREWFILE="/tmp/bootstrap-mac-Brewfile"
  echo "📥 Fetching baseline Brewfile..."
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
  if [ -t 0 ] || [ -c /dev/tty ]; then
    echo ""
    read -r -p "📋 Would you like to update/dump ~/.Brewfile with all currently installed packages? [y/N]: " REPLY_DUMP </dev/tty || REPLY_DUMP=""
    case "$REPLY_DUMP" in
      [yY][eE][sS]|[yY])
        DUMP_BREWFILE=true
        ;;
      *)
        DUMP_BREWFILE=false
        ;;
    esac
  else
    DUMP_BREWFILE=false
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

# 1. Zoxide: smart directory jumping (e.g. `z proj`)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# 2. FZF: interactive fuzzy history (Ctrl+R) and file picker (Ctrl+T)
if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

# 3. Modern CLI aliases (safe, plain output)
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

# 4. Guarded auto-suggestions and syntax highlighting (syntax-highlighting must load last)
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

if [ -f "$HOME/.gitignore_global" ]; then
  git config --global core.excludesfile "$HOME/.gitignore_global"
fi

killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

# 8. Optional Personal Dotfiles via Chezmoi
if [ -z "$RUN_DOTFILES" ]; then
  if [ -t 0 ] || [ -c /dev/tty ]; then
    echo ""
    echo "🔐 Optional Chezmoi Dotfiles Sync:"
    read -r -p "Would you like to apply a Chezmoi dotfiles repository? [y/N]: " REPLY </dev/tty || REPLY=""
    case "$REPLY" in
      [yY][eE][sS]|[yY])
        RUN_DOTFILES=true
        read -r -p "Enter Git repo (e.g. username/repo or full URL) [default: $DEFAULT_DOTFILES_REPO]: " USER_REPO </dev/tty || USER_REPO=""
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
  brew install chezmoi

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
  elif git ls-remote "$TEST_URL" HEAD >/dev/null 2>&1; then
    echo "🔓 Public repository accessible without credentials."
  else
    echo "🔒 Private repository detected. Setting up GitHub authentication..."
    brew install gh
    if ! gh auth status >/dev/null 2>&1; then
      echo "🌐 Authenticating with GitHub to access $DOTFILES_REPO..."
      gh auth login -p https -w
    fi
    gh auth setup-git
    DOTFILES_REPO="$TEST_URL"
  fi

  if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
    echo "📥 Pulling latest dotfile changes via Chezmoi..."
    chezmoi update --force
  else
    echo "📥 Initializing and applying dotfiles from $DOTFILES_REPO via Chezmoi..."
    chezmoi init --apply --force "$DOTFILES_REPO"
  fi
else
  echo "⏭️  Skipping Chezmoi dotfiles sync (minimal baseline bootstrap complete)."
fi

echo "✅ Mac bootstrap completed successfully!"
