#!/usr/bin/env bash

run_native_tap_script() {
  local native_script="$1"
  shift
  local native_tap_root="${NATIVE_TAP_ROOT:-}"
  local native_dot_files_root
  native_dot_files_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

  if [ -z "$native_tap_root" ]; then
    command -v brew >/dev/null || { printf 'Homebrew is required.\n' >&2; return 1; }
    native_tap_root="$(brew --repo marianposaceanu/tap)" || return
  fi
  if [ ! -f "$native_tap_root/native/$native_script" ]; then
    printf 'Native build script not found: %s/native/%s\n' "$native_tap_root" "$native_script" >&2
    printf 'Update marianposaceanu/tap, or set NATIVE_TAP_ROOT to a checkout containing native/.\n' >&2
    return 1
  fi
  export DOT_FILES_REPO="${DOT_FILES_REPO:-$native_dot_files_root}"
  exec bash "$native_tap_root/native/$native_script" "$@"
}
