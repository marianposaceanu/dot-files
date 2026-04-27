#!/usr/bin/env bash

set -euo pipefail

GHOSTTY_DIR="$HOME/Library/Application Support/com.mitchellh.ghostty"
CONFIG_PATH="$GHOSTTY_DIR/config"
BACKUP_PATH="$GHOSTTY_DIR/config.backup"

if [ ! -e "$CONFIG_PATH" ] && [ ! -L "$CONFIG_PATH" ]; then
  echo "No Ghostty config found at $CONFIG_PATH"
  exit 0
fi

if [ -L "$CONFIG_PATH" ]; then
  echo "Ghostty config is already a symlink; skipping backup move."
  exit 0
fi

backup_target="$BACKUP_PATH"
if [ -e "$backup_target" ] || [ -L "$backup_target" ]; then
  backup_target="$BACKUP_PATH.$(date +%Y%m%d%H%M%S)"
fi

mv "$CONFIG_PATH" "$backup_target"
echo "Moved Ghostty config to $backup_target"
