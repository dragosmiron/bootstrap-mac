#!/usr/bin/env bash
set -e

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

# 3. Chezmoi, GitHub CLI & Private Dotfiles
echo "⚙️  Installing Chezmoi and GitHub CLI..."
brew install chezmoi gh

# Determine Git authentication for private dotfiles
DOTFILES_REPO="git@github.com:dragosmiron/dotfiles-private.git"

if ! ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
  echo "🔑 SSH key not detected for GitHub. Checking GitHub CLI auth..."
  if ! gh auth status >/dev/null 2>&1; then
    echo "🌐 Authenticating with GitHub to pull private dotfiles..."
    gh auth login -p https -w
  fi
  gh auth setup-git
  DOTFILES_REPO="https://github.com/dragosmiron/dotfiles-private.git"
fi

if [ -d "$HOME/.local/share/chezmoi/.git" ]; then
  echo "📥 Pulling latest dotfile changes via Chezmoi..."
  chezmoi update --force
else
  echo "📥 Initializing and applying private dotfiles via Chezmoi..."
  chezmoi init --apply --force "$DOTFILES_REPO"
fi

# 4. Restore All Packages & Apps
if [ -f "$HOME/.Brewfile" ]; then
  echo "📦 Installing all applications and tools from Brewfile (adopting existing apps)..."
  brew bundle --file="$HOME/.Brewfile" --no-upgrade || brew bundle --file="$HOME/.Brewfile" || {
    echo "⚠️  Note: Some Brewfile packages or casks may require manual intervention or password prompt."
  }
fi

# 5. Install Rex Terminal (Direct Preview DMG)
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

# 6. macOS System Preferences
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

echo "✅ Mac bootstrap completed successfully!"
