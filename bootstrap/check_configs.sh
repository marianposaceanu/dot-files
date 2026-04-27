#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Checking shell script syntax..."
while IFS= read -r script; do
  bash -n "$script"
done < <(printf '%s\n' "$REPO_ROOT/bootstrap/remove_submodule.sh" "$REPO_ROOT/bootstrap/install_brew_deps.sh" "$REPO_ROOT/bootstrap/check_configs.sh" "$REPO_ROOT/benchmarks/profile_vim_plugins.sh" "$REPO_ROOT/benchmarks/profile_vim_plugins_median.sh")

echo "Checking Vim config load..."
vim -Nu "$REPO_ROOT/.vimrc" -i NONE -n -es -c 'qall'

if command -v ghostty >/dev/null 2>&1; then
  echo "Validating Ghostty config..."
  ghostty +validate-config >/dev/null
else
  echo "Skipping Ghostty validation (ghostty not found)."
fi

echo "All checks passed."
