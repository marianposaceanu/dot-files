#!/usr/bin/env bash
# bootstrap/compile_vim_native.sh
#
# Builds Vim from source with native Apple Silicon CPU optimisations, installs
# the binary into the existing Homebrew Cellar entry, and pins the formula so
# 'brew upgrade' does not overwrite the custom build.
#
# ── Why not 'brew reinstall --build-from-source'? ────────────────────────────
#
# Homebrew's superenv interceptsevery compiler call via shims in
#   /opt/homebrew/Library/Homebrew/shims/super/
# The shim's setup_build_environment() UNCONDITIONALLY overwrites any CFLAGS
# the caller set, replacing them with:
#   -Os              (optimize for size — worse than Vim's own -O2)
#   -march=armv8-a   (generic ARMv8-A — not apple-m4)
# Environment variables like CFLAGS= or HOMEBREW_OPTIMIZATION_LEVEL= set
# before calling brew are also overwritten inside setup_build_environment().
# The only way to use custom flags is to bypass the shim and call the real
# compiler (/usr/bin/clang) directly.
#
# ── Compiler flags ────────────────────────────────────────────────────────────
#
#   -O3
#       More aggressive optimisation than Homebrew's default.  Enables
#       additional inlining, loop unrolling, auto-vectorisation, and strength
#       reduction that -O2 conservatively skips.
#
#   -mcpu=native
#       On ARM this is the single correct flag — it combines -march (ISA) and
#       -mtune (micro-architecture scheduling) for the detected chip.  On this
#       machine it resolves to apple-m4.  Do NOT mix with -march or -mtune;
#       on ARM those flags override parts of -mcpu and produce worse code.
#
#   -ffp-contract=fast
#       Allows the compiler to fuse a*b+c into a single FMADD instruction
#       instead of two separate ops.  The M4 has high-throughput FMA units.
#       Safe for Vim: no user-visible computation depends on FP rounding order.
#
#   -flto
#       Link-time optimisation.  After all .o files are compiled, the linker
#       performs a second optimisation pass across the entire program: inlines
#       calls across translation units, eliminates dead functions, and fuses
#       small globals.  Increases link time but shrinks and speeds up the binary.
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
#   are present in both the Homebrew bottle and the native build.
#   The extensions above are the delta that -mcpu=apple-m4 adds over armv8-a.
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
  printf 'Error: Homebrew is not installed.\n' >&2; exit 1
fi

REAL_CLANG="/usr/bin/clang"
if [ ! -x "$REAL_CLANG" ]; then
  printf 'Error: %s not found. Install Xcode Command Line Tools.\n' "$REAL_CLANG" >&2; exit 1
fi

ARCH="$(uname -m)"
if [ "$ARCH" != "arm64" ]; then
  warn "This machine reports arch '$ARCH', not arm64. -mcpu=native will still work but gains may be smaller."
fi

# Report which Apple CPU -mcpu=native resolves to
RESOLVED_CPU="$("$REAL_CLANG" -mcpu=native -### -x c /dev/null 2>&1 \
  | grep -o 'apple-m[0-9]*' | tail -1 || echo 'unknown')"
info "-mcpu=native resolves to: ${RESOLVED_CPU}"

# ── Locate source tarball (download if not already cached) ────────────────────

VIM_VERSION="$(brew list --versions vim 2>/dev/null | awk '{print $2}')"
if [ -z "$VIM_VERSION" ]; then
  printf 'Error: vim is not installed via Homebrew.\n' >&2; exit 1
fi
info "Installed vim: ${VIM_VERSION}"

BREW_CACHE="$(brew --cache)"
SOURCE_TARBALL="$(ls "${BREW_CACHE}/downloads/"*"--vim-${VIM_VERSION}.tar.gz" 2>/dev/null | head -1 || true)"
if [ -z "$SOURCE_TARBALL" ]; then
  info "Downloading vim ${VIM_VERSION} source …"
  brew fetch --build-from-source vim
  SOURCE_TARBALL="$(ls "${BREW_CACHE}/downloads/"*"--vim-${VIM_VERSION}.tar.gz" 2>/dev/null | head -1)"
fi
if [ -z "$SOURCE_TARBALL" ]; then
  printf 'Error: Could not find vim %s source tarball in Homebrew cache.\n' "$VIM_VERSION" >&2; exit 1
fi
info "Source: $(basename "$SOURCE_TARBALL")"

# ── Extract to temp dir ───────────────────────────────────────────────────────

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

info "Extracting source …"
tar -xzf "$SOURCE_TARBALL" -C "$BUILD_DIR" --strip-components=1

# ── Configure ─────────────────────────────────────────────────────────────────

info "Configuring (same feature flags as Homebrew formula) …"
cd "$BUILD_DIR"
CC="$REAL_CLANG" \
./configure \
  --prefix=/opt/homebrew \
  --mandir=/opt/homebrew/share/man \
  --enable-multibyte \
  --with-tlib=ncurses \
  --with-compiledby=native-"${RESOLVED_CPU}" \
  --enable-cscope \
  --enable-terminal \
  --enable-perlinterp=dynamic \
  --enable-python3interp=dynamic \
  --enable-rubyinterp=dynamic \
  --disable-gui \
  --without-x \
  --enable-luainterp=dynamic \
  --with-lua-prefix="$(brew --prefix lua)" \
  2>&1 | tail -5

# ── Build ──────────────────────────────────────────────────────────────────────

info "Building vim with -O3 -mcpu=native -ffp-contract=fast -flto …"
make -j"$(sysctl -n hw.ncpu)" \
  CC="$REAL_CLANG" \
  CFLAGS="-g -O3 -mcpu=native -ffp-contract=fast -flto -D_REENTRANT -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=1" \
  LDFLAGS="-flto"

# ── Install binary into the Homebrew Cellar ───────────────────────────────────
#
# Only the compiled binary changes between flag sets; the runtime files
# (syntax, ftplugin, doc, etc.) are identical for the same version.

CELLAR_BIN="/opt/homebrew/Cellar/vim/${VIM_VERSION}/bin"
info "Installing binary to ${CELLAR_BIN} …"
chmod u+w "$CELLAR_BIN"
cp src/vim "$CELLAR_BIN/vim"
chmod 755 "$CELLAR_BIN/vim"

# ── Pin ────────────────────────────────────────────────────────────────────────

info "Pinning vim so 'brew upgrade' does not overwrite the custom build …"
brew pin vim

# ── Verify ────────────────────────────────────────────────────────────────────

success "Done."
printf '\n'
vim --version | head -4
printf '\n'

info "Embedded CFLAGS (confirmed in binary via strings):"
strings "$(command -v vim)" 2>/dev/null \
  | grep -E "/usr/bin/clang -c.*-O[0-9]" \
  | sed 's|^|  |'
printf '\n'

warn "vim is now pinned. To upgrade later:"
printf '    brew unpin vim && ./bootstrap/compile_vim_native.sh\n'
