#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <submodule-path>"
  exit 1
fi

SUBMODULE_PATH=$1

# Ensure the submodule path exists in the .gitmodules file
if ! grep -q "$SUBMODULE_PATH" .gitmodules; then
  echo "Error: Submodule path '$SUBMODULE_PATH' does not exist in .gitmodules."
  exit 1
fi

# Get the submodule name from .gitmodules
SUBMODULE_NAME=$(git config -f .gitmodules --name-only --get-regexp "submodule\..*\.path" | grep "$SUBMODULE_PATH" | sed 's/\.path//')
if [ -z "$SUBMODULE_NAME" ]; then
  echo "Error: Could not find submodule '$SUBMODULE_PATH' in .gitmodules."
  exit 1
fi

echo "Removing submodule '$SUBMODULE_NAME' at path '$SUBMODULE_PATH'..."

# Remove the submodule entry from .gitmodules
git config -f .gitmodules --remove-section "$SUBMODULE_NAME"

# Remove the submodule from the index
git rm --cached "$SUBMODULE_PATH"

# Remove the submodule's directory from the working tree
rm -rf "$SUBMODULE_PATH"

# Remove the submodule reference from .git/config
git config --remove-section "$SUBMODULE_NAME"

# Remove the submodule's directory from .git/modules
rm -rf ".git/modules/$SUBMODULE_PATH"

echo "Submodule '$SUBMODULE_NAME' removed successfully."
