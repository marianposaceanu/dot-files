#!/usr/bin/env bash
# bootstrap/compile_vim_native.sh
#
# Recompiles Vim from source using Homebrew's own formula with native
# Apple Silicon CPU optimisations, then pins the formula so brew upgrade
# does not overwrite the custom build.
#
# ── Compiler flags ────────────────────────────────────────────────────────────
#
#   -O3
#       More aggressive optimisation than Homebrew's default -O2. Enables
#       additional inlining, loop unrolling, auto-vectorisation, and strength
#       reduction that -O2 conservatively skips.
#
#   -mcpu=native
#       On ARM this is the single correct flag — it combines -march (ISA) and
#       -mtune (microarchitecture scheduling) for the detected chip. On this
#       machine it resolves to apple-m4. Do NOT mix with -march or -mtune;
#       on ARM those flags override parts of -mcpu and produce worse code.
#
#   -ffp-contract=fast
#       Allows the compiler to fuse a*b+c into a single FMADD instruction
#       instead of two separate ops. The M4 has high-throughput FMA units.
#       Safe for Vim: no user-visible computation depends on FP rounding order.
#
#   -flto
#       Link-time optimisation. After all .o files are compiled, the linker
#       performs a second optimisation pass across the entire program: inlines
#       calls across translation units, eliminates dead functions, and fuses
#       small globals. Increases link time but shrinks and speeds up the binary.
#
# ── M4-specific ISA extensions enabled by -mcpu=apple-m4 ─────────────────────
#
#   +bf16   BFloat16 — 16-bit brain float SIMD ops (ML / vectorised maths).
#   +i8mm   Int8 matrix multiply — hardware-accelerated 8-bit SIMD matmul.
#   +sme    Scalable Matrix Extension — large tiled matrix operations.
#   +sme2   SME version 2 — adds multi-vector and predicated ops over SME.
#   +v8.7a  ARMv8.7-A extensions including WFXT (efficient event waiting)
#           and XS (translation system hints for reduced TLB overhead).
#   +fpac   Pointer Authentication — hardware signing of return addresses
#           (security hardening; no performance impact for normal code).
#
#   Note: +aes, +sha2, +sha3, +neon, +crc, +dotprod, +fullfp16, +fp16fml
#   are present in both the generic bottle and the native build.
#   The extensions above are the delta that -mcpu=apple-m4 adds.
#
# ── Upgrade path ──────────────────────────────────────────────────────────────
#
#   brew unpin vim && ./bootstrap/compile_vim_native.sh
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

# Show the CFLAGS that ended up embedded in the binary
info "Embedded CFLAGS (from strings in binary):"
strings "$(command -v vim)" 2>/dev/null \
  | grep -E "^clang -c.*-O[0-9]" \
  | head -1 \
  | sed 's/clang -c/  clang -c/'
printf '\n'

warn "vim is now pinned. To upgrade later:"
printf '    brew unpin vim && ./bootstrap/compile_vim_native.sh\n'

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
