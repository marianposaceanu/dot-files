#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_PATH="$REPO_ROOT/ghostty/config"
GHOSTTY_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
CONFIG_PATH="$GHOSTTY_DIR/config"
BACKUP_STAMP="$(date +%Y%m%d%H%M%S)"

canonical_path() {
  local path="$1"
  local dir base

  dir="$(dirname "$path")"
  base="$(basename "$path")"

  if [ -d "$dir" ]; then
    (cd "$dir" && printf '%s/%s\n' "$(pwd -P)" "$base")
  else
    printf '%s\n' "$path"
  fi
}

canonical_link_target() {
  local raw_target

  raw_target="$(readlink "$CONFIG_PATH" 2>/dev/null || true)"
  if [ -z "$raw_target" ]; then
    printf '\n'
  elif [ "${raw_target#/}" = "$raw_target" ]; then
    canonical_path "$(dirname "$CONFIG_PATH")/$raw_target"
  else
    canonical_path "$raw_target"
  fi
}

next_backup_path() {
  local backup_path="${CONFIG_PATH}.backup.${BACKUP_STAMP}"
  local counter=1

  while [ -e "$backup_path" ] || [ -L "$backup_path" ]; do
    backup_path="${CONFIG_PATH}.backup.${BACKUP_STAMP}.${counter}"
    counter=$((counter + 1))
  done

  printf '%s\n' "$backup_path"
}

if [ ! -f "$SOURCE_PATH" ]; then
  printf 'Error: Ghostty config is missing: %s\n' "$SOURCE_PATH" >&2
  exit 1
fi

mkdir -p "$GHOSTTY_DIR"

if [ -L "$CONFIG_PATH" ] &&
  [ "$(canonical_link_target)" = "$(canonical_path "$SOURCE_PATH")" ]; then
  printf 'Already linked: %s -> %s\n' "$CONFIG_PATH" "$SOURCE_PATH"
  exit 0
fi

if [ -e "$CONFIG_PATH" ] || [ -L "$CONFIG_PATH" ]; then
  backup_path="$(next_backup_path)"
  mv "$CONFIG_PATH" "$backup_path"
  printf 'Backed up: %s -> %s\n' "$CONFIG_PATH" "$backup_path"
fi

ln -s "$SOURCE_PATH" "$CONFIG_PATH"
printf 'Linked: %s -> %s\n' "$CONFIG_PATH" "$SOURCE_PATH"
