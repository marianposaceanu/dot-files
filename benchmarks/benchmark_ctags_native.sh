#!/usr/bin/env bash
# Compatibility entry point for native-build and PGO callers.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bb --config "$REPO_ROOT/bb.edn" "$REPO_ROOT/benchmarks/benchmark_ctags_native.clj" "$@"
