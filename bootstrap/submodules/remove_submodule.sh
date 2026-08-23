#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <submodule-path>"
  exit 1
fi

SUBMODULE_PATH="$1"

if [ ! -f "$REPO_ROOT/.gitmodules" ]; then
  printf '╭─ COMMAND FAILED\n' >&2
  printf '╰─ .gitmodules was not found at the repository root.\n' >&2
  exit 1
fi

cd "$REPO_ROOT"

MATCHING_SECTIONS=()
while IFS= read -r section; do
  [ -n "$section" ] && MATCHING_SECTIONS+=("$section")
done < <(
  git config -f .gitmodules --get-regexp '^submodule\..*\.path$' \
    | awk -v p="$SUBMODULE_PATH" '$2 == p {sub(/\.path$/, "", $1); print $1}'
)

if [ "${#MATCHING_SECTIONS[@]}" -eq 0 ]; then
  printf '╭─ COMMAND FAILED\n' >&2
  printf "╰─ Submodule path '%s' does not exist in .gitmodules.\n" \
    "$SUBMODULE_PATH" >&2
  exit 1
fi

if [ "${#MATCHING_SECTIONS[@]}" -gt 1 ]; then
  printf '╭─ COMMAND FAILED\n' >&2
  printf "╰─ Multiple submodule sections match '%s'.\n" "$SUBMODULE_PATH" >&2
  printf '  • %s\n' "${MATCHING_SECTIONS[@]}" >&2
  exit 1
fi

SUBMODULE_NAME="${MATCHING_SECTIONS[0]}"

printf '╭─ REMOVE SUBMODULE\n'
printf "╰─ Removing '%s' from '%s'\n" "$SUBMODULE_NAME" "$SUBMODULE_PATH"

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

printf '\n╭─ SUBMODULE REMOVED\n'
printf "╰─ '%s' was removed successfully.\n" "$SUBMODULE_NAME"
