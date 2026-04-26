#!/usr/bin/env bash

set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Error: Homebrew is not installed or not in PATH." >&2
  exit 1
fi

FORMULAE=(
  fzf
  ripgrep
  bat
  universal-ctags
  tmux
  reattach-to-user-namespace
)

echo "Updating Homebrew metadata..."
brew update

for formula in "${FORMULAE[@]}"; do
  if brew list --formula "$formula" >/dev/null 2>&1; then
    echo "Upgrading $formula..."
    brew upgrade "$formula" || true
  else
    echo "Installing $formula..."
    brew install "$formula"
  fi
done

echo "Done."
