#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd -P)"

[ "$#" -le 1 ] || { printf 'Usage: %s [--remote]\n' "$0" >&2; exit 2; }
case "${1:-}" in
  '')
    update_args=(--init --recursive)
    update_message='Updating submodules to repository-pinned revisions...'
    ;;
  --remote)
    update_args=(--init --remote --recursive)
    update_message='Updating submodules from configured remotes...'
    ;;
  -h|--help) printf 'Usage: %s [--remote]\n' "$0"; exit 0 ;;
  *) printf 'Usage: %s [--remote]\n' "$0" >&2; exit 2 ;;
esac

printf '╭─ VIM PLUGIN SUBMODULES\n'
if [ "${1:-}" = '--remote' ]; then
  printf '╰─ Updating from configured remotes\n'
else
  printf '╰─ Restoring repository-pinned revisions\n'
fi
printf '• %s\n' "$update_message"
git -C "$REPO_ROOT" submodule --quiet sync --recursive
git -C "$REPO_ROOT" submodule --quiet update "${update_args[@]}"
printf '\n╭─ SUBMODULES COMPLETE\n'
printf '╰─ Submodules are up to date.\n'
