#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"

printf '╭─ DOT-FILES :: CONFIG CHECKS\n'
printf '╰─ Validating scripts, generated pages, Vim, and Ghostty\n'

printf '• Checking shell script syntax...\n'
while IFS= read -r script; do
  bash -n "$script"
done < <(find "$REPO_ROOT/bootstrap" -type f -name '*.sh' -print | sort; printf '%s\n' "$REPO_ROOT/benchmarks/benchmark_ripgrep_native.sh" "$REPO_ROOT/benchmarks/benchmark_ctags_native.sh" "$REPO_ROOT/benchmarks/benchmark_git_native.sh" "$REPO_ROOT/benchmarks/profile_vim_plugins.sh" "$REPO_ROOT/benchmarks/profile_vim_plugins_median.sh")

printf '• Checking Zsh config syntax...\n'
zsh -n "$REPO_ROOT/.zprofile"
zsh -n "$REPO_ROOT/.zshrc"
zsh -n "$REPO_ROOT/.zlogin"

printf '• Checking macOS installer idempotence...\n'
env -u GEM_HOME -u GEM_PATH ruby "$REPO_ROOT/test/install_macos_test.rb"

printf '• Checking generated tutorial pages...\n'
env -u GEM_HOME -u GEM_PATH ruby \
  "$REPO_ROOT/bootstrap/site/build_tutorial_pages.rb" --check

printf '• Checking published site contract...\n'
env -u GEM_HOME -u GEM_PATH ruby "$REPO_ROOT/bootstrap/site/validate_site.rb"

printf '• Checking Vim config load...\n'
vim -Nu "$REPO_ROOT/.vimrc" -i NONE -n -es -c 'qall'

if command -v ghostty >/dev/null 2>&1; then
  printf '• Validating Ghostty config...\n'
  ghostty +validate-config >/dev/null
else
  printf '• Skipping Ghostty validation (ghostty not found).\n'
fi

printf '\n╭─ CHECKS COMPLETE\n'
printf '╰─ All configuration checks passed.\n'
