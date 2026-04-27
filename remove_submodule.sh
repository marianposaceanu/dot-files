#!/usr/bin/env bash

set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <submodule-path>"
  exit 1
fi

SUBMODULE_PATH="$1"

if [ ! -f .gitmodules ]; then
  echo "Error: .gitmodules not found in current directory."
  exit 1
fi

MATCHING_SECTIONS=()
while IFS= read -r section; do
  [ -n "$section" ] && MATCHING_SECTIONS+=("$section")
done < <(
  git config -f .gitmodules --get-regexp '^submodule\..*\.path$' \
    | awk -v p="$SUBMODULE_PATH" '$2 == p {sub(/\.path$/, "", $1); print $1}'
)

if [ "${#MATCHING_SECTIONS[@]}" -eq 0 ]; then
  echo "Error: Submodule path '$SUBMODULE_PATH' does not exist in .gitmodules."
  exit 1
fi

if [ "${#MATCHING_SECTIONS[@]}" -gt 1 ]; then
  echo "Error: Multiple submodule sections match '$SUBMODULE_PATH'."
  printf ' - %s\n' "${MATCHING_SECTIONS[@]}"
  exit 1
fi

SUBMODULE_NAME="${MATCHING_SECTIONS[0]}"

echo "Removing submodule '$SUBMODULE_NAME' at path '$SUBMODULE_PATH'..."

# Deinitialize and remove submodule from index/working tree.
git submodule deinit -f -- "$SUBMODULE_PATH" >/dev/null 2>&1 || true
git rm -f "$SUBMODULE_PATH"

# Ensure the submodule entry is removed from .gitmodules and stage it.
if git config -f .gitmodules --get-regexp "^${SUBMODULE_NAME//./\\.}\\.path$" >/dev/null 2>&1; then
  git config -f .gitmodules --remove-section "$SUBMODULE_NAME"
fi
git add .gitmodules

# Remove local submodule config if present.
if git config --get-regexp "^${SUBMODULE_NAME//./\.}(\.|$)" >/dev/null 2>&1; then
  git config --remove-section "$SUBMODULE_NAME" || true
fi

# Remove submodule metadata.
rm -rf ".git/modules/$SUBMODULE_PATH"

echo "Submodule '$SUBMODULE_NAME' removed successfully."
