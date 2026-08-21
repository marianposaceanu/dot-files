#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BREWFILE="$REPO_ROOT/Brewfile"
WARNINGS=0

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
  OK_LABEL="$(printf '\033[1;32mOK:\033[0m')"
  INFO_LABEL="$(printf '\033[1;34mInfo:\033[0m')"
  WARNING_LABEL="$(printf '\033[1;33mWarning:\033[0m')"
else
  OK_LABEL='OK:'
  INFO_LABEL='Info:'
  WARNING_LABEL='Warning:'
fi

warn() {
  printf '%s %s\n' "$WARNING_LABEL" "$1"
  WARNINGS=$((WARNINGS + 1))
}

ok() {
  printf '%s %s\n' "$OK_LABEL" "$1"
}

info() {
  printf '%s %s\n' "$INFO_LABEL" "$1"
}

section() {
  printf '\n==> %s\n' "$1"
}

canonical_path() {
  local path="$1"

  if [ -d "$path" ]; then
    (cd "$path" 2>/dev/null && pwd -P) || printf '%s\n' "$path"
    return
  fi

  local dir base
  dir="$(dirname "$path")"
  base="$(basename "$path")"

  if [ -d "$dir" ]; then
    (cd "$dir" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$base")
  else
    printf '%s\n' "$path"
  fi
}

active_vim_is_custom_brew_build() {
  local active_vim brew_vim_prefix vim_version

  active_vim="$(command -v vim 2>/dev/null || true)"
  brew_vim_prefix="$(brew --prefix vim 2>/dev/null || true)"
  [ -n "$active_vim" ] && [ -x "$active_vim" ] || return 1
  [ -n "$brew_vim_prefix" ] && [ -x "$brew_vim_prefix/bin/vim" ] || return 1
  [ "$active_vim" -ef "$brew_vim_prefix/bin/vim" ] || return 1

  vim_version="$("$active_vim" --version 2>/dev/null || true)"
  printf '%s\n' "$vim_version" | grep -Eq '^Compiled by native-apple-m[0-9]+$'
}

brew_formula_is_pinned() {
  brew list --pinned 2>/dev/null | grep -qx "$1"
}

canonical_link_target() {
  local link_path="$1"
  local raw_target resolved_target

  raw_target="$(readlink "$link_path" 2>/dev/null || true)"
  if [ -z "$raw_target" ]; then
    printf '\n'
    return
  fi

  if [ "${raw_target#/}" = "$raw_target" ]; then
    resolved_target="$(dirname "$link_path")/$raw_target"
  else
    resolved_target="$raw_target"
  fi

  canonical_path "$resolved_target"
}

check_symlink() {
  local link_path="$1"
  local expected_target="$2"
  local label="$3"
  local expected_real actual_real raw_target

  if [ ! -e "$link_path" ] && [ ! -L "$link_path" ]; then
    warn "$label is missing ($link_path)"
    return
  fi

  if [ ! -L "$link_path" ]; then
    warn "$label exists but is not a symlink ($link_path)"
    return
  fi

  expected_real="$(canonical_path "$expected_target")"
  actual_real="$(canonical_link_target "$link_path")"

  if [ "$actual_real" = "$expected_real" ]; then
    ok "$label -> $expected_target"
    return
  fi

  raw_target="$(readlink "$link_path" 2>/dev/null || true)"
  warn "$label points to '$raw_target' (expected '$expected_target')"
}

check_symlink_capability() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  touch "$tmp_dir/target"
  if ln -s "$tmp_dir/target" "$tmp_dir/link" >/dev/null 2>&1 && [ -L "$tmp_dir/link" ]; then
    ok 'filesystem supports symlink creation'
  else
    warn 'unable to create a symlink on this filesystem/session'
  fi

  rm -rf "$tmp_dir"
}

check_brew_deps() {
  local formulas
  local formula
  local outdated
  local missing_count
  local outdated_count

  if ! command -v brew >/dev/null 2>&1; then
    warn 'Homebrew is not installed or not in PATH; skipping Brewfile checks'
    return
  fi

  if [ ! -f "$BREWFILE" ]; then
    warn "Brewfile not found at $BREWFILE"
    return
  fi

  formulas=()
  while IFS= read -r formula; do
    [ -n "$formula" ] || continue
    formulas+=("$formula")
  done < <(awk '/^brew "/ {print $2}' "$BREWFILE" | tr -d '"')

  if [ "${#formulas[@]}" -eq 0 ]; then
    warn 'Brewfile has no brew formula entries'
    return
  fi

  missing_count=0
  for formula in "${formulas[@]}"; do
    if ! brew list --versions "$formula" >/dev/null 2>&1; then
      warn "missing brew formula: $formula"
      missing_count=$((missing_count + 1))
    fi
  done

  if [ "$missing_count" -eq 0 ]; then
    ok 'all Brewfile formulas are installed'
  fi

  outdated="$(brew outdated --formula --quiet 2>/dev/null || true)"
  outdated_count=0
  for formula in "${formulas[@]}"; do
    if printf '%s\n' "$outdated" | grep -qx "$formula"; then
      outdated_count=$((outdated_count + 1))
      if [ "$formula" = 'vim' ] && active_vim_is_custom_brew_build; then
        if brew_formula_is_pinned vim; then
          info 'Homebrew has a Vim update, but the active Vim is custom compiled and pinned; rebuild it when ready'
        else
          warn 'Homebrew has a Vim update and the active Vim is custom compiled but not pinned; run brew pin vim or rebuild it'
        fi
      else
        warn "outdated brew formula: $formula"
      fi
    fi
  done

  if [ "$outdated_count" -eq 0 ]; then
    ok 'no outdated Brewfile formulas'
  fi
}

printf 'dot-files doctor\n'

section 'Symlink checks'
check_symlink_capability
check_symlink "$HOME/.vimrc" "$REPO_ROOT/.vimrc" '~/.vimrc'
check_symlink "$HOME/.vim" "$REPO_ROOT/.vim" '~/.vim'
check_symlink "$HOME/.gitconfig" "$REPO_ROOT/.gitconfig" '~/.gitconfig'
check_symlink "$HOME/.gitignore_global" "$REPO_ROOT/.gitignore_global" '~/.gitignore_global'
check_symlink "$HOME/.tmux.conf" "$REPO_ROOT/.tmux.conf" '~/.tmux.conf'
check_symlink "$HOME/.zprofile" "$REPO_ROOT/.zprofile" '~/.zprofile'
check_symlink "$HOME/.zshrc" "$REPO_ROOT/.zshrc" '~/.zshrc'
check_symlink "$HOME/.zlogin" "$REPO_ROOT/.zlogin" '~/.zlogin'
check_symlink "$HOME/.bashrc" "$REPO_ROOT/.bashrc" '~/.bashrc'

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  warn 'oh-my-zsh not installed (~/.oh-my-zsh missing); see https://github.com/ohmyzsh/ohmyzsh'
fi

if command -v mextdisplay >/dev/null 2>&1; then
  ok 'mextdisplay is installed'
else
  warn 'mextdisplay is not installed; run bootstrap/install_macos.sh'
fi

BAT_CONFIG_DIR="$HOME/.config/bat"
if command -v bat >/dev/null 2>&1 || [ -e "$BAT_CONFIG_DIR" ] || [ -L "$BAT_CONFIG_DIR" ]; then
  check_symlink "$BAT_CONFIG_DIR" "$REPO_ROOT/bat" 'bat config'
else
  printf 'Info: skipping bat config symlink check (bat not detected)\n'
fi

GHOSTTY_SYMLINK="$HOME/Library/Application Support/com.mitchellh.ghostty/config"
if command -v ghostty >/dev/null 2>&1 || [ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ]; then
  ok 'Ghostty is installed'
else
  warn 'Ghostty is not installed; run bootstrap/install_macos.sh'
fi

if [ -e "$GHOSTTY_SYMLINK" ] || [ -L "$GHOSTTY_SYMLINK" ]; then
  check_symlink "$GHOSTTY_SYMLINK" "$REPO_ROOT/ghostty/config" 'Ghostty config'
else
  warn "Ghostty config is missing ($GHOSTTY_SYMLINK)"
fi

section 'Brew checks'
check_brew_deps

printf '\n'
if [ "$WARNINGS" -eq 0 ]; then
  printf 'No issues found.\n'
else
  printf 'Found %d warning(s).\n' "$WARNINGS"
  exit 1
fi
