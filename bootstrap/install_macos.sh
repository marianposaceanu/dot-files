#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
EXPECTED_REPO="$HOME/dot-files"
GHOSTTY_APP_PATH="${GHOSTTY_APP_PATH:-/Applications/Ghostty.app}"
OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
SKIP_CHECKS=0
OH_MY_ZSH_TMP=''

usage() {
  cat <<'EOF'
Usage: ./bootstrap/install_macos.sh [--skip-checks]

Install the macOS tools used by this repository, initialize Vim submodules,
and link the managed configuration files into $HOME. Existing destinations
are preserved with timestamped backups by bootstrap/link_configs.sh.

Options:
  --skip-checks  Skip the final config and environment validation.
  -h, --help     Show this help.
EOF
}

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

section() {
  printf '\n==> %s\n' "$1"
}

cleanup() {
  if [ -n "$OH_MY_ZSH_TMP" ] && { [ -e "$OH_MY_ZSH_TMP" ] || [ -L "$OH_MY_ZSH_TMP" ]; }; then
    rm -rf "$OH_MY_ZSH_TMP"
  fi
}
trap cleanup EXIT

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-checks)
      SKIP_CHECKS=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown option: $1"
      ;;
  esac
  shift
done

if [ "$(uname -s)" != 'Darwin' ]; then
  die 'this installer supports macOS only'
fi

section 'Checking Apple Command Line Tools'
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install >/dev/null 2>&1 || true
  die 'Command Line Tools installation was requested; finish it, then rerun this installer'
fi
printf 'Apple Command Line Tools are available.\n'

section 'Ensuring the repository path'
if [ -d "$EXPECTED_REPO" ]; then
  expected_real="$(cd "$EXPECTED_REPO" && pwd -P)"
  if [ "$expected_real" != "$REPO_ROOT" ]; then
    die "$EXPECTED_REPO points to $expected_real instead of $REPO_ROOT"
  fi
  printf 'Repository path is ready: %s\n' "$EXPECTED_REPO"
elif [ -e "$EXPECTED_REPO" ] || [ -L "$EXPECTED_REPO" ]; then
  die "$EXPECTED_REPO exists but is not this repository"
else
  ln -s "$REPO_ROOT" "$EXPECTED_REPO"
  printf 'Linked repository path: %s -> %s\n' "$EXPECTED_REPO" "$REPO_ROOT"
fi

find_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
  elif [ -x /opt/homebrew/bin/brew ]; then
    printf '/opt/homebrew/bin/brew\n'
  elif [ -x /usr/local/bin/brew ]; then
    printf '/usr/local/bin/brew\n'
  else
    printf '\n'
  fi
}

section 'Ensuring Homebrew'
BREW_BIN="$(find_brew)"
if [ -z "$BREW_BIN" ]; then
  command -v curl >/dev/null 2>&1 || die 'curl is required to install Homebrew'
  printf 'Installing Homebrew...\n'
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  BREW_BIN="$(find_brew)"
  [ -n "$BREW_BIN" ] || die 'Homebrew installation completed but brew was not found'
else
  printf 'Homebrew is already installed: %s\n' "$BREW_BIN"
fi
eval "$("$BREW_BIN" shellenv)"

section 'Installing command-line dependencies'
"$REPO_ROOT/bootstrap/install_brew_deps.sh"
RUBY_PREFIX="$("$BREW_BIN" --prefix ruby)"
[ -x "$RUBY_PREFIX/bin/ruby" ] || die "Homebrew Ruby is missing from $RUBY_PREFIX"
export PATH="$RUBY_PREFIX/bin:$PATH"
VIM_PREFIX="$("$BREW_BIN" --prefix vim)"
[ -x "$VIM_PREFIX/bin/vim" ] || die "Homebrew Vim is missing from $VIM_PREFIX"

find_ghostty() {
  if command -v ghostty >/dev/null 2>&1; then
    command -v ghostty
  elif [ -x "$GHOSTTY_APP_PATH/Contents/MacOS/ghostty" ]; then
    printf '%s/Contents/MacOS/ghostty\n' "$GHOSTTY_APP_PATH"
  else
    printf '\n'
  fi
}

section 'Ensuring Ghostty'
GHOSTTY_BIN="$(find_ghostty)"
if [ -n "$GHOSTTY_BIN" ]; then
  printf 'Ghostty is already installed.\n'
elif "$BREW_BIN" list --cask ghostty >/dev/null 2>&1; then
  printf 'Repairing the Homebrew Ghostty installation...\n'
  HOMEBREW_NO_AUTO_UPDATE=1 "$BREW_BIN" reinstall --cask ghostty
else
  HOMEBREW_NO_AUTO_UPDATE=1 "$BREW_BIN" install --cask ghostty
fi
GHOSTTY_BIN="$(find_ghostty)"
[ -n "$GHOSTTY_BIN" ] || die "Ghostty was installed but its executable is missing from $GHOSTTY_APP_PATH"

section 'Ensuring Oh My Zsh'
if [ -f "$OH_MY_ZSH_DIR/oh-my-zsh.sh" ]; then
  printf 'Oh My Zsh is already installed: %s\n' "$OH_MY_ZSH_DIR"
elif [ -e "$OH_MY_ZSH_DIR" ] || [ -L "$OH_MY_ZSH_DIR" ]; then
  die "$OH_MY_ZSH_DIR exists but is not a complete Oh My Zsh installation"
else
  mkdir -p "$(dirname "$OH_MY_ZSH_DIR")"
  oh_my_zsh_candidate="${OH_MY_ZSH_DIR}.install.$$"
  [ ! -e "$oh_my_zsh_candidate" ] && [ ! -L "$oh_my_zsh_candidate" ] \
    || die "temporary installation path already exists: $oh_my_zsh_candidate"
  OH_MY_ZSH_TMP="$oh_my_zsh_candidate"
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$OH_MY_ZSH_TMP"
  mv "$OH_MY_ZSH_TMP" "$OH_MY_ZSH_DIR"
  OH_MY_ZSH_TMP=''
fi

section 'Initializing pinned Vim plugins'
git -C "$REPO_ROOT" submodule sync --recursive
git -C "$REPO_ROOT" submodule update --init --recursive

section 'Linking configuration files'
"$REPO_ROOT/bootstrap/link_configs.sh"

if [ "$SKIP_CHECKS" -eq 0 ]; then
  section 'Validating the installation'
  "$REPO_ROOT/bootstrap/check_configs.sh"
  "$GHOSTTY_BIN" +validate-config >/dev/null
  "$REPO_ROOT/bootstrap/doctor.sh"
else
  printf '\nSkipped final checks. Run these when ready:\n'
  printf '  %s/bootstrap/check_configs.sh\n' "$REPO_ROOT"
  printf '  %s/bootstrap/doctor.sh\n' "$REPO_ROOT"
fi

printf '\nmacOS setup is complete. Restart the terminal or run: source ~/.zshrc\n'
