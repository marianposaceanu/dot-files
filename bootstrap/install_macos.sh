#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"

if [ "$(uname -s)" != 'Darwin' ]; then
  printf '✗ Error: this installer supports macOS only.\n' >&2
  exit 1
fi

case "${1:-}" in
  -h|--help)
    cat <<'EOF'
Usage: bootstrap/install_macos.sh [--skip-checks] [--timings]

Options:
  --skip-checks  Skip final repository and environment checks
  --timings      Print elapsed time for each setup stage
  -h, --help     Show this help
EOF
    exit 0
    ;;
esac

if command -v bb >/dev/null 2>&1; then
  exec bb "$REPO_ROOT/bootstrap/install_macos.clj" "$@"
fi

if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install >/dev/null 2>&1 || true
  printf '✗ Error: Command Line Tools installation was requested; finish it, then rerun this installer.\n' >&2
  exit 1
fi

find_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
  elif [ -x /opt/homebrew/bin/brew ]; then
    printf '/opt/homebrew/bin/brew\n'
  elif [ -x /usr/local/bin/brew ]; then
    printf '/usr/local/bin/brew\n'
  fi
}

BREW_BIN="$(find_brew)"
if [ -z "$BREW_BIN" ]; then
  command -v curl >/dev/null 2>&1 || {
    printf '✗ Error: curl is required to install Homebrew.\n' >&2
    exit 1
  }
  printf '• Installing Homebrew...\n'
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  BREW_BIN="$(find_brew)"
  [ -n "$BREW_BIN" ] || {
    printf '✗ Error: Homebrew installation completed but brew was not found.\n' >&2
    exit 1
  }
fi

eval "$("$BREW_BIN" shellenv)"

printf '• Installing Babashka...\n'
"$BREW_BIN" install borkdude/brew/babashka

exec bb "$REPO_ROOT/bootstrap/install_macos.clj" "$@"
