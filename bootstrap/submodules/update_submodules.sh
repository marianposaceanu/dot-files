#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"

[ "$#" -le 1 ] || { printf 'Usage: %s [--remote]\n' "$0" >&2; exit 2; }
case "${1:-}" in
  '') update_args=(--init --recursive) ;;
  --remote) update_args=(--init --remote --recursive) ;;
  -h|--help) printf 'Usage: %s [--remote]\n' "$0"; exit 0 ;;
  *) printf 'Usage: %s [--remote]\n' "$0" >&2; exit 2 ;;
esac

git -C "$REPO_ROOT" submodule --quiet sync --recursive
git -C "$REPO_ROOT" submodule --quiet update "${update_args[@]}"
