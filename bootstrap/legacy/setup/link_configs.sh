#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
BACKUP_STAMP="$(date +%Y%m%d%H%M%S)"
SUMMARY=0
UNCHANGED_COUNT=0
LINKED_COUNT=0
BACKUP_COUNT=0

if [ "${1:-}" = '--summary' ]; then
  SUMMARY=1
  shift
fi

if [ "$#" -ne 0 ]; then
  printf 'Usage: %s [--summary]\n' "$0" >&2
  exit 1
fi

LINK_SPECS=(
  ".vimrc|$HOME/.vimrc"
  ".vim|$HOME/.vim"
  ".gitconfig|$HOME/.gitconfig"
  ".gitignore_global|$HOME/.gitignore_global"
  ".tmux.conf|$HOME/.tmux.conf"
  ".zprofile|$HOME/.zprofile"
  ".zshrc|$HOME/.zshrc"
  ".zlogin|$HOME/.zlogin"
  ".bashrc|$HOME/.bashrc"
  "codex/config.toml|$HOME/.codex/config.toml"
  "amp/settings.json|$HOME/.config/amp/settings.json"
  "bat|$HOME/.config/bat"
  "ghostty/config|$HOME/Library/Application Support/com.mitchellh.ghostty/config"
)

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

next_backup_path() {
  local path="$1"
  local backup_path="${path}.backup.${BACKUP_STAMP}"
  local counter=1

  while [ -e "$backup_path" ] || [ -L "$backup_path" ]; do
    backup_path="${path}.backup.${BACKUP_STAMP}.${counter}"
    counter=$((counter + 1))
  done

  printf '%s\n' "$backup_path"
}

link_config() {
  local source_rel="$1"
  local link_path="$2"
  local source_path="$REPO_ROOT/$source_rel"
  local link_parent backup_path

  if [ ! -e "$source_path" ] && [ ! -L "$source_path" ]; then
    printf '╭─ COMMAND FAILED\n' >&2
    printf '╰─ Source config is missing: %s\n' "$source_path" >&2
    exit 1
  fi

  link_parent="$(dirname "$link_path")"
  mkdir -p "$link_parent"

  if [ -L "$link_path" ]; then
    if [ "$(canonical_link_target "$link_path")" = "$(canonical_path "$source_path")" ]; then
      UNCHANGED_COUNT=$((UNCHANGED_COUNT + 1))
      if [ "$SUMMARY" -eq 0 ]; then
        printf 'Already linked: %s -> %s\n' "$link_path" "$source_path"
      fi
      return
    fi
  fi

  if [ -e "$link_path" ] || [ -L "$link_path" ]; then
    backup_path="$(next_backup_path "$link_path")"
    mv "$link_path" "$backup_path"
    BACKUP_COUNT=$((BACKUP_COUNT + 1))
    if [ "$SUMMARY" -eq 0 ]; then
      printf 'Backed up: %s -> %s\n' "$link_path" "$backup_path"
    fi
  fi

  ln -s "$source_path" "$link_path"
  LINKED_COUNT=$((LINKED_COUNT + 1))
  if [ "$SUMMARY" -eq 0 ]; then
    printf 'Linked: %s -> %s\n' "$link_path" "$source_path"
  fi
}

if [ "$SUMMARY" -eq 0 ]; then
  printf '╭─ CONFIGURATION LINKS\n'
  printf '╰─ Linking managed dot-files into your home directory\n'
fi

for spec in "${LINK_SPECS[@]}"; do
  link_config "${spec%%|*}" "${spec#*|}"
done

if [ "$SUMMARY" -eq 1 ]; then
  if [ "$BACKUP_COUNT" -eq 1 ]; then
    printf '%d unchanged, %d updated, 1 backup.\n' \
      "$UNCHANGED_COUNT" "$LINKED_COUNT"
  else
    printf '%d unchanged, %d updated, %d backups.\n' \
      "$UNCHANGED_COUNT" "$LINKED_COUNT" "$BACKUP_COUNT"
  fi
else
  printf '\n╭─ LINKS COMPLETE\n'
  if [ "$BACKUP_COUNT" -eq 1 ]; then
    printf '╰─ %d unchanged, %d updated, 1 backup.\n' \
      "$UNCHANGED_COUNT" "$LINKED_COUNT"
  else
    printf '╰─ %d unchanged, %d updated, %d backups.\n' \
      "$UNCHANGED_COUNT" "$LINKED_COUNT" "$BACKUP_COUNT"
  fi
fi
