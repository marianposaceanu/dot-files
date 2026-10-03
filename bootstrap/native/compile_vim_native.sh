#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/native_tap.sh"
run_native_tap_script compile_vim_native.sh "$@"
