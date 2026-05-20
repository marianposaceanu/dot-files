#!/usr/bin/env bash
# bootstrap/compile_vim_native.sh
#
# Recompiles Vim from source using Homebrew's own formula with native
# Apple Silicon CPU optimisations, then pins the formula so brew upgrade
# does not overwrite the custom build.
#
# Flags used and what they do:
#   -O3               More aggressive optimisation than Homebrew's default -O2:
#                     more inlining, loop unrolling, vectorisation.
#   -mcpu=native      On ARM, combines -march + -mtune for the detected chip.
#                     On M4 this resolves to apple-m4, enabling ISA extensions
#                     the generic bottle misses: bf16, i8mm, sme/sme2, v8.7a.
#   -ffp-contract=fast Allow a*b+c to be fused into a single FMADD instruction.
#                     The M4 has excellent FMA throughput. Safe for Vim (no
#                     user-facing floating-point results depend on rounding).
#   -flto             Link-time optimisation: cross-module inlining and dead-code
#                     removal after all translation units are compiled.
#
# To upgrade Vim later, run this script again after 'brew unpin vim'.
#
# Usage:
#   ./bootstrap/compile_vim_native.sh

set -euo pipefail

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
  BOLD="$(printf '\033[1m')"
  GREEN="$(printf '\033[1;32m')"
  YELLOW="$(printf '\033[1;33m')"
  RESET="$(printf '\033[0m')"
else
  BOLD="" GREEN="" YELLOW="" RESET=""
fi

info()    { printf '%s==>%s %s\n' "$BOLD" "$RESET" "$1"; }
success() { printf '%s==>%s %s\n' "$GREEN" "$RESET" "$1"; }
warn()    { printf '%s==>%s %s\n' "$YELLOW" "$RESET" "$1"; }

# ── Preflight ──────────────────────────────────────────────────────────────────

if ! command -v brew >/dev/null 2>&1; then
  printf 'Error: Homebrew is not installed.\n' >&2
  exit 1
fi

ARCH="$(uname -m)"
if [ "$ARCH" != "arm64" ]; then
  warn "This machine reports arch '$ARCH', not arm64. -mcpu=native will still work but gains may be smaller."
fi

# Report which Apple CPU -mcpu=native resolves to (requires clang)
if command -v clang >/dev/null 2>&1; then
  RESOLVED_CPU="$(clang -mcpu=native -### -x c /dev/null 2>&1 | grep -o 'apple-m[0-9]*' | tail -1 || echo 'unknown')"
  info "-mcpu=native resolves to: ${RESOLVED_CPU}"
fi

# ── Show current state ─────────────────────────────────────────────────────────

CURRENT_VERSION="$(brew list --versions vim 2>/dev/null | awk '{print $2}' || echo 'not installed')"
info "Current vim: $CURRENT_VERSION ($(which vim 2>/dev/null || echo 'not in PATH'))"

# ── Build ──────────────────────────────────────────────────────────────────────

info "Building vim from source with -O3 -mcpu=native -ffp-contract=fast -flto …"
CFLAGS="-O3 -mcpu=native -ffp-contract=fast -flto" \
LDFLAGS="-flto" \
  brew reinstall --build-from-source vim

# ── Pin ────────────────────────────────────────────────────────────────────────

info "Pinning vim so 'brew upgrade' does not overwrite the custom build …"
brew pin vim

# ── Verify ────────────────────────────────────────────────────────────────────

success "Done."
printf '\n'
vim --version | head -3
printf '\n'
warn "vim is now pinned. To upgrade later:"
printf '    brew unpin vim && ./bootstrap/compile_vim_native.sh\n'
