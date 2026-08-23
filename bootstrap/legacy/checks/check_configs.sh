#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

echo "Checking shell script syntax..."
while IFS= read -r script; do
  bash -n "$script"
done < <(find "$REPO_ROOT/bootstrap" -type f -name '*.sh' -print | sort; printf '%s\n' "$REPO_ROOT/benchmarks/benchmark_ripgrep_native.sh" "$REPO_ROOT/benchmarks/benchmark_ctags_native.sh" "$REPO_ROOT/benchmarks/benchmark_git_native.sh" "$REPO_ROOT/benchmarks/profile_vim_plugins.sh" "$REPO_ROOT/benchmarks/profile_vim_plugins_median.sh")

echo "Checking Zsh config syntax..."
zsh -n "$REPO_ROOT/.zprofile"
zsh -n "$REPO_ROOT/.zshrc"
zsh -n "$REPO_ROOT/.zlogin"

echo "Checking macOS installer idempotence..."
env -u GEM_HOME -u GEM_PATH ruby "$REPO_ROOT/test/install_macos_test.rb"

echo "Checking tutorial page generator..."
env -u GEM_HOME -u GEM_PATH ruby -c "$REPO_ROOT/bootstrap/site/build_tutorial_pages.rb" >/dev/null

echo "Checking published site contract..."
env -u GEM_HOME -u GEM_PATH ruby "$REPO_ROOT/bootstrap/site/validate_site.rb"

echo "Checking Vim config load..."
vim -Nu "$REPO_ROOT/.vimrc" -i NONE -n -es -c 'qall'

if command -v ghostty >/dev/null 2>&1; then
  echo "Validating Ghostty config..."
  ghostty +validate-config >/dev/null
else
  echo "Skipping Ghostty validation (ghostty not found)."
fi

echo "All checks passed."
