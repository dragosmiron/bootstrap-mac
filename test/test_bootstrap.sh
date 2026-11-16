#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_SCRIPT="$SCRIPT_DIR/../bootstrap.sh"

PASSED=0
FAILED=0
OUT=""
RC=0

assert_eq() {
  local label="$1"
  local actual="$2"
  local expected="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  ✅ $label: $actual"
    PASSED=$((PASSED + 1))
  else
    echo "  ❌ $label: expected '$expected', got '$actual'"
    FAILED=$((FAILED + 1))
  fi
}

assert_contains() {
  local label="$1"
  local haystack="$2"
  local needle="$3"
  case "$haystack" in
    *"$needle"*) echo "  ✅ $label"; PASSED=$((PASSED + 1)) ;;
    *) echo "  ❌ $label: '$needle' not found in output"; FAILED=$((FAILED + 1)) ;;
  esac
}

# Runs any command, capturing output in OUT and status in RC without aborting the suite.
capture() {
  set +e
  OUT="$("$@" 2>&1)"
  RC=$?
  set -e
}

# Extracts a KEY=value line printed by parse-only mode.
field() {
  printf '%s\n' "$OUT" | sed -n "s/^$1=//p"
}

parse() {
  capture env BOOTSTRAP_PARSE_ONLY=1 "$BOOTSTRAP_SCRIPT" "$@"
  assert_eq "parse exit ($*)" "$RC" "0"
}

parse_env() {
  capture env BOOTSTRAP_PARSE_ONLY=1 "$@" "$BOOTSTRAP_SCRIPT"
  assert_eq "parse exit ($*)" "$RC" "0"
}

echo "=== Running bootstrap-mac Test Suite ==="

echo "[1] Syntax Check"
capture bash -n "$BOOTSTRAP_SCRIPT"
assert_eq "bash -n bootstrap.sh" "$RC" "0"

echo "[2] Help Flags"
capture "$BOOTSTRAP_SCRIPT" --help
assert_eq "--help exit code" "$RC" "0"
assert_contains "--help output contains Usage" "$OUT" "Usage: ./bootstrap.sh"
capture "$BOOTSTRAP_SCRIPT" -h
assert_eq "-h exit code" "$RC" "0"
assert_contains "-h output contains Usage" "$OUT" "Usage: ./bootstrap.sh"

echo "[3] Unknown Options"
capture "$BOOTSTRAP_SCRIPT" --invalid-flag
assert_eq "--invalid-flag exit code" "$RC" "1"
assert_contains "Unknown option error message" "$OUT" "Unknown option: --invalid-flag"

capture "$BOOTSTRAP_SCRIPT" --full
assert_eq "removed --full is rejected" "$RC" "1"
capture "$BOOTSTRAP_SCRIPT" --repo=https://github.com/me/d.git
assert_eq "removed --repo alias is rejected" "$RC" "1"

echo "[4] Flag Parsing"

parse --minimal
assert_eq "--minimal RUN_DOTFILES" "$(field RUN_DOTFILES)" "false"
assert_eq "--minimal DOTFILES_REPO" "$(field DOTFILES_REPO)" ""

capture env BOOTSTRAP_PARSE_ONLY=1 "$BOOTSTRAP_SCRIPT" --dotfiles=
assert_eq "--dotfiles= empty value exit code" "$RC" "1"
assert_contains "--dotfiles= empty value message" "$OUT" "no repository URL"

parse --dotfiles=git@github.com:me/dotfiles.git
assert_eq "--dotfiles=<scp url> RUN_DOTFILES" "$(field RUN_DOTFILES)" "true"
assert_eq "--dotfiles=<scp url> DOTFILES_REPO" "$(field DOTFILES_REPO)" "git@github.com:me/dotfiles.git"

parse --dotfiles https://gitlab.com/me/dots.git
assert_eq "--dotfiles <https url> RUN_DOTFILES" "$(field RUN_DOTFILES)" "true"
assert_eq "--dotfiles <https url> DOTFILES_REPO" "$(field DOTFILES_REPO)" "https://gitlab.com/me/dots.git"

parse --dotfiles=ssh://git@example.com:2222/me/dots.git
assert_eq "--dotfiles=<ssh url> RUN_DOTFILES" "$(field RUN_DOTFILES)" "true"
assert_eq "--dotfiles=<ssh url> DOTFILES_REPO" "$(field DOTFILES_REPO)" "ssh://git@example.com:2222/me/dots.git"

# A bare owner/repo slug is rejected: users paste the clone URL GitHub shows them.
capture env BOOTSTRAP_PARSE_ONLY=1 "$BOOTSTRAP_SCRIPT" --dotfiles dragosmiron/dotfiles-private
assert_eq "bare slug exit code" "$RC" "1"
assert_contains "bare slug message" "$OUT" "Invalid dotfiles repository"

capture env BOOTSTRAP_PARSE_ONLY=1 "$BOOTSTRAP_SCRIPT" --dotfiles
assert_eq "--dotfiles without value exit code" "$RC" "1"
assert_contains "--dotfiles without value message" "$OUT" "requires a repository URL"

# Only clone URLs git and GitHub actually hand you are accepted (no plain http://)
capture env BOOTSTRAP_PARSE_ONLY=1 "$BOOTSTRAP_SCRIPT" --dotfiles=http://example.com/me/d.git
assert_eq "http:// url exit code" "$RC" "1"
assert_contains "http:// url message" "$OUT" "Invalid dotfiles repository"

parse --cli-only
assert_eq "--cli-only CLI_ONLY" "$(field CLI_ONLY)" "true"
assert_eq "--cli-only RUN_DOTFILES" "$(field RUN_DOTFILES)" "false"

parse --cli-only --dotfiles=https://github.com/me/d.git
assert_eq "--cli-only --dotfiles CLI_ONLY" "$(field CLI_ONLY)" "true"
assert_eq "--cli-only --dotfiles RUN_DOTFILES" "$(field RUN_DOTFILES)" "true"

parse --dotfiles=https://github.com/me/d.git --cli-only
assert_eq "--dotfiles --cli-only CLI_ONLY" "$(field CLI_ONLY)" "true"
assert_eq "--dotfiles --cli-only RUN_DOTFILES" "$(field RUN_DOTFILES)" "true"

parse --dotfiles=https://github.com/me/d.git --minimal
assert_eq "--dotfiles --minimal RUN_DOTFILES" "$(field RUN_DOTFILES)" "false"
assert_eq "--dotfiles --minimal DOTFILES_REPO" "$(field DOTFILES_REPO)" ""

parse --dump
assert_eq "--dump DUMP_BREWFILE" "$(field DUMP_BREWFILE)" "true"
parse --no-dump
assert_eq "--no-dump DUMP_BREWFILE" "$(field DUMP_BREWFILE)" "false"

echo "[5] Environment Variable Parsing"

parse_env BOOTSTRAP_MINIMAL=1
assert_eq "BOOTSTRAP_MINIMAL=1 RUN_DOTFILES" "$(field RUN_DOTFILES)" "false"

parse_env BOOTSTRAP_CLI_ONLY=1
assert_eq "BOOTSTRAP_CLI_ONLY=1 CLI_ONLY" "$(field CLI_ONLY)" "true"
assert_eq "BOOTSTRAP_CLI_ONLY=1 RUN_DOTFILES" "$(field RUN_DOTFILES)" "false"

parse_env BOOTSTRAP_DUMP=1
assert_eq "BOOTSTRAP_DUMP=1 DUMP_BREWFILE" "$(field DUMP_BREWFILE)" "true"

parse_env BOOTSTRAP_DOTFILES=https://github.com/me/env-dotfiles.git
assert_eq "BOOTSTRAP_DOTFILES RUN_DOTFILES" "$(field RUN_DOTFILES)" "true"
assert_eq "BOOTSTRAP_DOTFILES DOTFILES_REPO" "$(field DOTFILES_REPO)" "https://github.com/me/env-dotfiles.git"

capture env BOOTSTRAP_PARSE_ONLY=1 BOOTSTRAP_DOTFILES=me/env-dotfiles "$BOOTSTRAP_SCRIPT"
assert_eq "BOOTSTRAP_DOTFILES slug exit code" "$RC" "1"
assert_contains "BOOTSTRAP_DOTFILES slug message" "$OUT" "Invalid dotfiles repository"

echo "[6] Brewfile Bundle Integrity"
capture brew bundle check --no-upgrade --file="$SCRIPT_DIR/../Brewfile"
assert_eq "Brewfile bundle check (--no-upgrade)" "$RC" "0"

echo "[7] normalize_link and parse_ssh_remote Unit Tests"
# Source the helper functions directly from bootstrap.sh
eval "$(sed -n '/^normalize_link() {/,/^}/p' "$BOOTSTRAP_SCRIPT")"
eval "$(sed -n '/^parse_ssh_remote() {/,/^}/p' "$BOOTSTRAP_SCRIPT")"

assert_eq "scp ssh -> host/path" "$(normalize_link 'git@github.com:me/dots.git')" "github.com/me/dots"
assert_eq "https -> host/path" "$(normalize_link 'https://github.com/me/dots.git')" "github.com/me/dots"
assert_eq "group/sub path preserved" "$(normalize_link 'git@gitlab.com:group/sub/dots.git')" "gitlab.com/group/sub/dots"
# Port from ssh:// URL is stripped; .git suffix removed in both paths
assert_eq "ssh:// with explicit port stripped" "$(normalize_link 'ssh://git@example.com:2222/repo.git')" "example.com/repo"
assert_eq "ssh:// no port falls through" "$(normalize_link 'ssh://git@example.com/repo.git')" "example.com/repo"
assert_eq "same repo cross-format match" "$(normalize_link 'git@github.com:me/dots.git')" "$(normalize_link 'https://github.com/me/dots.git')" "cross-format identity"

# parse_ssh_remote coverage
parse_ssh_remote "git@github.com:user/repo.git"
assert_eq "parse_ssh_remote scp user" "$SSH_USER" "git"
assert_eq "parse_ssh_remote scp host" "$SSH_HOST" "github.com"
assert_eq "parse_ssh_remote scp port" "$SSH_PORT" ""

parse_ssh_remote "ssh://customuser@gitlab.example.com:2222/group/repo.git"
assert_eq "parse_ssh_remote ssh:// custom user" "$SSH_USER" "customuser"
assert_eq "parse_ssh_remote ssh:// host" "$SSH_HOST" "gitlab.example.com"
assert_eq "parse_ssh_remote ssh:// custom port" "$SSH_PORT" "2222"

parse_ssh_remote "ssh://server.lan/repo.git"
assert_eq "parse_ssh_remote ssh:// default user" "$SSH_USER" "git"
assert_eq "parse_ssh_remote ssh:// host no port" "$SSH_HOST" "server.lan"
assert_eq "parse_ssh_remote ssh:// no port" "$SSH_PORT" ""

echo ""
echo "=== Summary: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -ne 0 ]; then
  exit 1
fi