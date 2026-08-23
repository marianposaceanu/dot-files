#!/usr/bin/env bash

set -euo pipefail

GHOSTTY_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
CONFIG_PATH="$GHOSTTY_DIR/config"
BACKUP_PATH="$GHOSTTY_DIR/config.backup"

if [ ! -e "$CONFIG_PATH" ] && [ ! -L "$CONFIG_PATH" ]; then
  printf '╭─ GHOSTTY CONFIG\n'
  printf '╰─ No existing config found; nothing to back up.\n'
  exit 0
fi

if [ -L "$CONFIG_PATH" ]; then
  printf '╭─ GHOSTTY CONFIG\n'
  printf '╰─ Config is already a symlink; nothing to back up.\n'
  exit 0
fi

backup_target="$BACKUP_PATH"
if [ -e "$backup_target" ] || [ -L "$backup_target" ]; then
  backup_target="$BACKUP_PATH.$(date +%Y%m%d%H%M%S)"
fi

mv "$CONFIG_PATH" "$backup_target"
printf '╭─ GHOSTTY BACKUP COMPLETE\n'
printf '╰─ Moved the existing config to %s\n' "$backup_target"
