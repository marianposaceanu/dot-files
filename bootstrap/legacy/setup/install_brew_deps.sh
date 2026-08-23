#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BREWFILE="$REPO_ROOT/Brewfile"

if ! command -v brew >/dev/null 2>&1; then
  printf '╭─ COMMAND FAILED\n' >&2
  printf '╰─ Homebrew is not installed or not in PATH.\n' >&2
  exit 1
fi

if [ ! -f "$BREWFILE" ]; then
  printf '╭─ COMMAND FAILED\n' >&2
  printf '╰─ Brewfile not found at %s\n' "$BREWFILE" >&2
  exit 1
fi

printf '╭─ HOMEBREW DEPENDENCIES\n'
printf '╰─ Installing the repository Brewfile\n'

printf '• Updating Homebrew metadata...\n'
brew update

printf '• Installing dependencies from Brewfile...\n'
if brew bundle --help 2>/dev/null | grep -q -- '--no-lock'; then
  brew bundle --file "$BREWFILE" --no-lock
else
  brew bundle --file "$BREWFILE"
fi

printf '\n╭─ DEPENDENCIES COMPLETE\n'
printf '╰─ Brewfile dependencies are installed.\n'
