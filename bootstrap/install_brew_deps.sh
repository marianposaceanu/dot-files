#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BREWFILE="$REPO_ROOT/Brewfile"

if ! command -v brew >/dev/null 2>&1; then
  echo "Error: Homebrew is not installed or not in PATH." >&2
  exit 1
fi

if [ ! -f "$BREWFILE" ]; then
  echo "Error: Brewfile not found at $BREWFILE" >&2
  exit 1
fi

echo "Updating Homebrew metadata..."
brew update

echo "Installing dependencies from Brewfile..."
if brew bundle --help 2>/dev/null | grep -q -- '--no-lock'; then
  brew bundle --file "$BREWFILE" --no-lock
else
  brew bundle --file "$BREWFILE"
fi

echo "Done."
