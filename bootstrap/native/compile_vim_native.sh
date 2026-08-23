#!/usr/bin/env bash
# bootstrap/native/compile_vim_native.sh
#
# Builds Vim from source with native Apple Silicon CPU optimisations, installs
# the binary into the existing Homebrew Cellar entry, and pins the formula so
# 'brew upgrade' does not overwrite the custom build.
#
# ── Why not 'brew reinstall --build-from-source'? ────────────────────────────
#
# Homebrew's superenv intercepts every compiler call via shims in
#   /opt/homebrew/Library/Homebrew/shims/super/
# The shim's setup_build_environment() UNCONDITIONALLY overwrites any CFLAGS
# the caller set, replacing them with:
#   -Os              (optimize for size — worse than Vim's own -O2)
#   -march=armv8-a   (generic ARMv8-A — not the local Apple CPU)
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
#       machine it resolves to the current Apple CPU family, such as apple-m1.
#       Do NOT mix with -march or -mtune; on ARM those flags override parts of
#       -mcpu and produce worse code.
#
#   -ffp-contract=fast
#       Allows the compiler to fuse a*b+c into a single FMADD instruction
#       instead of two separate ops. This permits different intermediate
#       floating-point rounding and is an accepted performance trade-off for
#       this local Vim build.
#
#   -flto
#       Link-time optimisation.  After all .o files are compiled, the linker
#       performs a second optimisation pass across the entire program: inlines
#       calls across translation units, eliminates dead functions, and fuses
#       small globals.  Increases link time but shrinks and speeds up the binary.
#
# ── Apple CPU-specific ISA extensions enabled by -mcpu=native ────────────────
#
#   The exact feature set depends on the machine. On this M1 Pro, clang resolves
#   -mcpu=native to apple-m1; newer chips may resolve to apple-m2/apple-m3/etc.
#
#   Use clang's -### output to inspect the exact target CPU and features used
#   on the current machine.
#
# ── Upgrade path ──────────────────────────────────────────────────────────────
#
#   brew unpin vim && brew upgrade vim && ./bootstrap/native/compile_vim_native.sh
#
# Usage:
#   ./bootstrap/native/compile_vim_native.sh

set -euo pipefail

fail() {
  printf '╭─ NATIVE VIM BUILD FAILED\n' >&2
  printf '╰─ %s\n' "$1" >&2
  exit 1
}

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
  CYAN="$(printf '\033[1;36m')"
  GREEN="$(printf '\033[1;32m')"
  YELLOW="$(printf '\033[1;33m')"
  RESET="$(printf '\033[0m')"
else
  CYAN="" GREEN="" YELLOW="" RESET=""
fi

info()    { printf '%s•%s %s\n' "$CYAN" "$RESET" "$1"; }
success() { printf '\n%s╭─ NATIVE VIM BUILD COMPLETE%s\n╰─ %s\n' "$GREEN" "$RESET" "$1"; }
warn()    { printf '%s!%s %s\n' "$YELLOW" "$RESET" "$1"; }

printf '%s╭─ NATIVE VIM BUILD%s\n' "$CYAN" "$RESET"
printf '╰─ Rebuilding the active Homebrew binary for this Apple CPU\n'

OPTIMIZATION_FLAGS="-O3 -mcpu=native -ffp-contract=fast -flto"

sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

formula_dependency() {
  sed -n 's/^[[:space:]]*depends_on "\([^"]*\)".*/\1/p' "$FORMULA" \
    | grep "^$1" \
    | head -1
}

require_formula_text() {
  grep -Fq -- "$1" "$FORMULA" \
    || fail "Installed Vim formula changed (missing: $1). Update this script before rebuilding."
}

require_formula_dependency() {
  local dependency="$1"
  brew list --versions "$dependency" >/dev/null 2>&1 \
    || fail "Homebrew dependency '$dependency' is not installed."
}

is_vim_pinned() {
  brew list --pinned | grep -Fxq vim
}

verify_vim() {
  local candidate="$1"
  local version_output linkage rpaths test_dir actual expected

  [ -x "$candidate" ] || fail "Candidate is not executable: $candidate"
  [ "$(lipo -archs "$candidate")" = "arm64" ] \
    || fail "Candidate is not a thin arm64 binary: $candidate"
  codesign --verify --strict "$candidate" \
    || fail "Candidate code signature is invalid: $candidate"

  version_output="$("$candidate" --version)"
  printf '%s\n' "$version_output" | grep -Fq "VIM - Vi IMproved ${VIM_SERIES}" \
    || fail "Candidate does not report Vim ${VIM_SERIES}."
  printf '%s\n' "$version_output" | grep -Fq "Included patches: 1-${VIM_PATCH}" \
    || fail "Candidate does not report patch ${VIM_PATCH}."
  printf '%s\n' "$version_output" | grep -Fq "Compiled by native-${RESOLVED_CPU}" \
    || fail "Candidate does not report compiled-by native-${RESOLVED_CPU}."
  for flag in -O3 -mcpu=native -ffp-contract=fast -flto; do
    printf '%s\n' "$version_output" | grep -Fq -- "$flag" \
      || fail "Candidate does not report compiler flag $flag."
  done
  for feature in gettext sodium perl python3 ruby lua; do
    printf '%s\n' "$version_output" | grep -Eq "(^|[[:space:]])\\+${feature}(/dyn)?([[:space:]]|$)" \
      || fail "Candidate is missing +${feature}."
  done

  linkage="$(otool -L "$candidate")"
  for prefix in "$NCURSES_PREFIX" "$GETTEXT_PREFIX" "$LIBSODIUM_PREFIX"; do
    printf '%s\n' "$linkage" | grep -Fq "$prefix/lib/" \
      || fail "Candidate is not linked to ${prefix}/lib."
  done

  rpaths="$(otool -l "$candidate" | awk '
    $1 == "cmd" && $2 == "LC_RPATH" { in_rpath = 1; next }
    in_rpath && $1 == "path" { print $2; in_rpath = 0 }
  ')"
  for prefix in "$LUA_PREFIX" "$PYTHON_PREFIX" "$RUBY_PREFIX"; do
    printf '%s\n' "$rpaths" | grep -Fxq "$prefix/lib" \
      || fail "Candidate is missing runtime path ${prefix}/lib."
  done

  test_dir="$(mktemp -d "${TMPDIR:-/tmp}/vim-native-test.XXXXXX")"
  cat >"$test_dir/commands.vim" <<'VIM'
:python3 import vim; vim.current.buffer[0] = 'hello python3'
:ruby Vim::Buffer.current.append(0, 'hello ruby')
:perl $curbuf->Append(0, "hello perl")
:lua vim.buffer():insert("hello lua")
:wq
VIM
  if ! "$candidate" -Nu NONE -i NONE -n -T dumb -s \
    "$test_dir/commands.vim" "$test_dir/test.txt" \
    >"$test_dir/stdout" 2>"$test_dir/stderr"; then
    cat "$test_dir/stderr" >&2
    rm -rf "$test_dir"
    fail "Candidate interpreter smoke test failed to execute."
  fi
  actual="$(cat "$test_dir/test.txt" 2>/dev/null || true)"
  expected="$(printf 'hello perl\nhello ruby\nhello python3\nhello lua')"
  if [ "$actual" != "$expected" ]; then
    cat "$test_dir/stderr" >&2
    rm -rf "$test_dir"
    fail "Candidate failed the Perl, Ruby, Python, and Lua smoke test."
  fi
  rm -rf "$test_dir"
}

# ── Preflight ──────────────────────────────────────────────────────────────────

if ! command -v brew >/dev/null 2>&1; then
  fail "Homebrew is not installed."
fi
BREW_PREFIX="$(brew --prefix)"

REAL_CLANG="/usr/bin/clang"
if [ ! -x "$REAL_CLANG" ]; then
  fail "$REAL_CLANG not found. Install Xcode Command Line Tools."
fi

ARCH="$(uname -m)"
[ "$ARCH" = "arm64" ] \
  || fail "This script only supports native Apple Silicon; uname reports '$ARCH'."

# Report which Apple CPU -mcpu=native resolves to
RESOLVED_CPU="$("$REAL_CLANG" -mcpu=native -### -x c /dev/null 2>&1 \
  | grep -o 'apple-m[0-9]*' | tail -1 || true)"
[ -n "$RESOLVED_CPU" ] \
  || fail "Could not resolve -mcpu=native to an Apple CPU family."
info "-mcpu=native resolves to: ${RESOLVED_CPU}"

# ── Resolve the active keg and its formula contract ───────────────────────────

OPT_PREFIX="$(brew --prefix vim 2>/dev/null || true)"
[ -d "$OPT_PREFIX" ] || fail "Vim is not installed via Homebrew."
KEG="$(cd "$OPT_PREFIX" && pwd -P)"
case "$KEG" in
  "$BREW_PREFIX/Cellar/vim/"*) ;;
  *) fail "Homebrew Vim prefix does not resolve to a Vim Cellar keg: $KEG" ;;
esac

VIM_VERSION="$(basename "$KEG")"
TARGET="$KEG/bin/vim"
FORMULA="$KEG/.brew/vim.rb"
[ -x "$TARGET" ] || fail "Active Vim target is missing or not executable: $TARGET"
[ -f "$FORMULA" ] || fail "Installed formula snapshot is missing: $FORMULA"

VIM_SERIES="$(printf '%s' "$VIM_VERSION" | awk -F. '{print $1 "." $2}')"
PATCH_COMPONENT="${VIM_VERSION##*.}"
VIM_PATCH="$(printf '%s' "$PATCH_COMPONENT" | sed 's/^0*//')"
[ -n "$VIM_PATCH" ] || VIM_PATCH=0

SOURCE_URL="$(sed -n 's/^[[:space:]]*url "\([^"]*\)".*/\1/p' "$FORMULA" | head -1)"
SOURCE_SHA256="$(sed -n 's/^[[:space:]]*sha256 "\([0-9a-fA-F]*\)".*/\1/p' "$FORMULA" | head -1)"
[ -n "$SOURCE_URL" ] || fail "Could not read the source URL from $FORMULA"
printf '%s' "$SOURCE_URL" | grep -Fq "v${VIM_VERSION}.tar.gz" \
  || fail "Formula source URL does not match active Vim ${VIM_VERSION}: $SOURCE_URL"
printf '%s' "$SOURCE_SHA256" | grep -Eq '^[0-9a-fA-F]{64}$' \
  || fail "Formula source SHA-256 is missing or invalid."

for text in \
  'depends_on "gettext"' \
  'depends_on "lua"' \
  'depends_on "ruby"' \
  'depends_on "libsodium"' \
  'depends_on "ncurses"' \
  '"--enable-multibyte"' \
  '"--enable-cscope"' \
  '"--enable-terminal"' \
  '"--enable-python3interp=dynamic"' \
  '"--enable-rubyinterp=dynamic"' \
  '"--enable-luainterp=dynamic"' \
  '"--disable-gui"' \
  '"--without-x"'; do
  require_formula_text "$text"
done

PYTHON_FORMULA="$(formula_dependency 'python@')"
[ -n "$PYTHON_FORMULA" ] \
  || fail "Could not determine the formula's Python dependency."

for dependency in gettext lua "$PYTHON_FORMULA" ruby libsodium ncurses; do
  require_formula_dependency "$dependency"
done
[ -x /usr/bin/perl ] || fail "The macOS Perl interpreter is unavailable."

GETTEXT_PREFIX="$(brew --prefix gettext)"
LUA_PREFIX="$(brew --prefix lua)"
PYTHON_PREFIX="$(brew --prefix "$PYTHON_FORMULA")"
RUBY_PREFIX="$(brew --prefix ruby)"
LIBSODIUM_PREFIX="$(brew --prefix libsodium)"
NCURSES_PREFIX="$(brew --prefix ncurses)"
PYTHON3="$PYTHON_PREFIX/bin/python3"
[ -x "$PYTHON3" ] || fail "Homebrew Python is missing: $PYTHON3"

info "Installed vim: ${VIM_VERSION}"
info "Formula snapshot: ${FORMULA}"

if is_vim_pinned; then
  WAS_PINNED=1
else
  WAS_PINNED=0
fi

# ── Locate and verify the exact source archive ────────────────────────────────

BREW_CACHE="$(brew --cache)"
DOWNLOADS_DIR="$BREW_CACHE/downloads"
mkdir -p "$DOWNLOADS_DIR"
SOURCE_TARBALL=""
for candidate in "$DOWNLOADS_DIR"/*"--vim-${VIM_VERSION}.tar.gz" \
  "$DOWNLOADS_DIR/manual-vim-${VIM_VERSION}-${SOURCE_SHA256}.tar.gz"; do
  [ -f "$candidate" ] || continue
  if [ "$(sha256 "$candidate")" = "$SOURCE_SHA256" ]; then
    SOURCE_TARBALL="$candidate"
    break
  fi
  warn "Ignoring cached source with the wrong checksum: $candidate"
done

if [ -z "$SOURCE_TARBALL" ]; then
  SOURCE_TARBALL="$DOWNLOADS_DIR/manual-vim-${VIM_VERSION}-${SOURCE_SHA256}.tar.gz"
  PARTIAL_TARBALL="${SOURCE_TARBALL}.partial.$$"
  info "Downloading exact Vim ${VIM_VERSION} source …"
  curl -fL "$SOURCE_URL" -o "$PARTIAL_TARBALL"
  if [ "$(sha256 "$PARTIAL_TARBALL")" != "$SOURCE_SHA256" ]; then
    rm -f "$PARTIAL_TARBALL"
    fail "Downloaded Vim source failed SHA-256 verification."
  fi
  mv "$PARTIAL_TARBALL" "$SOURCE_TARBALL"
fi
EXPECTED_SOURCE_SHA256="$SOURCE_SHA256"
[ "$(sha256 "$SOURCE_TARBALL")" = "$EXPECTED_SOURCE_SHA256" ] \
  || fail "Vim source archive failed SHA-256 verification."
info "Source: $(basename "$SOURCE_TARBALL")"
info "Source SHA-256: ${SOURCE_SHA256}"

# ── Extract to temp dir ───────────────────────────────────────────────────────

BUILD_DIR="$(mktemp -d)"
STAGED_TARGET=""
BACKUP_TARGET=""
CELLAR_BIN="$(dirname "$TARGET")"
CELLAR_BIN_MODE="$(stat -f '%Lp' "$CELLAR_BIN")"
TARGET_MODE="$(stat -f '%Lp' "$TARGET")"
COMMITTED=0

cleanup() {
  local status="$?"
  trap - EXIT INT TERM
  set +e
  if [ "$COMMITTED" -ne 1 ] && [ -n "$BACKUP_TARGET" ] \
    && [ -f "$BACKUP_TARGET" ]; then
    warn "Restoring the previous Vim binary after failure …"
    if mv -f "$BACKUP_TARGET" "$TARGET"; then
      BACKUP_TARGET=""
    else
      warn "Could not restore $TARGET; backup retained at $BACKUP_TARGET"
      status=1
    fi
  fi
  [ -n "$STAGED_TARGET" ] && rm -f "$STAGED_TARGET"
  if ! chmod "$CELLAR_BIN_MODE" "$CELLAR_BIN" 2>/dev/null; then
    warn "Could not restore directory mode $CELLAR_BIN_MODE on $CELLAR_BIN"
    status=1
  fi
  if [ "$COMMITTED" -ne 1 ]; then
    if [ "$WAS_PINNED" -eq 1 ]; then
      brew pin vim >/dev/null 2>&1 || true
      if ! is_vim_pinned; then
        warn "Could not restore Vim's original pinned state."
        status=1
      fi
    else
      brew unpin vim >/dev/null 2>&1 || true
      if is_vim_pinned; then
        warn "Could not restore Vim's original unpinned state."
        status=1
      fi
    fi
  fi
  rm -rf "$BUILD_DIR"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

info "Extracting source …"
tar -xzf "$SOURCE_TARBALL" -C "$BUILD_DIR" --strip-components=1

# Reuse Vim's centered MODIFIED_BY intro line to describe this native build.
perl -pi -e 's/\Q(char_u *)_("Modified by ")\E/(char_u *)_("Optimized for ")/' "$BUILD_DIR/src/version.c"
grep -Fq '(char_u *)_("Optimized for ")' "$BUILD_DIR/src/version.c" \
  || fail "Could not customize Vim intro text."

# ── Configure ─────────────────────────────────────────────────────────────────

info "Configuring with the installed Homebrew formula's feature contract …"
cd "$BUILD_DIR"
BUILD_PATH="$PYTHON_PREFIX/bin:$PYTHON_PREFIX/libexec/bin:$RUBY_PREFIX/bin:$GETTEXT_PREFIX/bin:/usr/bin:/bin:/usr/sbin:/sbin"
BUILD_CFLAGS="-g ${OPTIMIZATION_FLAGS} -D_REENTRANT -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=1"
BUILD_CPPFLAGS="-I$GETTEXT_PREFIX/include -I$NCURSES_PREFIX/include -I$LIBSODIUM_PREFIX/include"
BUILD_LDFLAGS="-flto -L$GETTEXT_PREFIX/lib -L$NCURSES_PREFIX/lib -L$LIBSODIUM_PREFIX/lib"
for prefix in "$LUA_PREFIX" "$PYTHON_PREFIX" "$RUBY_PREFIX"; do
  BUILD_LDFLAGS="$BUILD_LDFLAGS -Wl,-rpath,$prefix/lib"
done
BUILD_PKG_CONFIG_PATH="$GETTEXT_PREFIX/lib/pkgconfig:$NCURSES_PREFIX/lib/pkgconfig:$LIBSODIUM_PREFIX/lib/pkgconfig:$LUA_PREFIX/lib/pkgconfig:$RUBY_PREFIX/lib/pkgconfig"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

env -i \
  HOME="$HOME" \
  TMPDIR="${TMPDIR:-/tmp}" \
  PATH="$BUILD_PATH" \
  SDKROOT="$SDKROOT" \
  CC="$REAL_CLANG" \
  CFLAGS="$BUILD_CFLAGS" \
  CPPFLAGS="$BUILD_CPPFLAGS" \
  LDFLAGS="$BUILD_LDFLAGS" \
  PKG_CONFIG_PATH="$BUILD_PKG_CONFIG_PATH" \
./configure \
  --prefix="$BREW_PREFIX" \
  --mandir="$BREW_PREFIX/share/man" \
  --enable-multibyte \
  --with-tlib=ncurses \
  --with-compiledby=native-"${RESOLVED_CPU}" \
  --with-modified-by="[ ${RESOLVED_CPU} :: ${OPTIMIZATION_FLAGS} ]" \
  --enable-cscope \
  --enable-terminal \
  --enable-perlinterp \
  --enable-python3interp=dynamic \
  --with-python3-command="$PYTHON3" \
  --enable-rubyinterp=dynamic \
  --disable-gui \
  --without-x \
  --enable-luainterp=dynamic \
  --with-lua-prefix="$LUA_PREFIX" \
  2>&1 | tail -5

# ── Build ──────────────────────────────────────────────────────────────────────

info "Building vim with ${OPTIMIZATION_FLAGS} …"
env -i \
  HOME="$HOME" \
  TMPDIR="${TMPDIR:-/tmp}" \
  PATH="$BUILD_PATH" \
  SDKROOT="$SDKROOT" \
  CC="$REAL_CLANG" \
  CFLAGS="$BUILD_CFLAGS" \
  CPPFLAGS="$BUILD_CPPFLAGS" \
  LDFLAGS="$BUILD_LDFLAGS" \
  PKG_CONFIG_PATH="$BUILD_PKG_CONFIG_PATH" \
make -j"$(sysctl -n hw.ncpu)"

# ── Verify, atomically install, and verify again ──────────────────────────────
#
# Only the compiled binary changes between flag sets; the runtime files
# (syntax, ftplugin, doc, etc.) are identical for the same version.

info "Verifying the candidate before touching the Cellar …"
verify_vim "$BUILD_DIR/src/vim"

STAGED_TARGET="$CELLAR_BIN/.vim.native-stage.$$"
BACKUP_TARGET="$CELLAR_BIN/.vim.native-backup.$$"
info "Staging native Vim in ${CELLAR_BIN} …"
chmod u+w "$CELLAR_BIN"
cp "$BUILD_DIR/src/vim" "$STAGED_TARGET"
chmod "$TARGET_MODE" "$STAGED_TARGET"
verify_vim "$STAGED_TARGET"

cp -p "$TARGET" "$BACKUP_TARGET"
info "Atomically replacing ${TARGET} …"
mv -f "$STAGED_TARGET" "$TARGET"
STAGED_TARGET=""

verify_vim "$TARGET"
[ "$(sha256 "$TARGET")" = "$(sha256 "$BUILD_DIR/src/vim")" ] \
  || fail "Installed Vim does not match the verified candidate."

# ── Pin ────────────────────────────────────────────────────────────────────────

info "Pinning vim so 'brew upgrade' does not overwrite the custom build …"
brew pin vim || fail "Could not pin the verified custom Vim build."

COMMITTED=1
rm -f "$BACKUP_TARGET"
BACKUP_TARGET=""
chmod "$CELLAR_BIN_MODE" "$CELLAR_BIN"

# ── Verify ────────────────────────────────────────────────────────────────────

info "Final verification complete."
printf '\n'
"$TARGET" --version | head -4
printf '\n'

info "Embedded compiler command (recorded by Vim; functional checks also passed):"
strings "$TARGET" 2>/dev/null \
  | grep -E "/usr/bin/clang -c.*-O[0-9]" \
  | sed 's|^|  |'
printf '\n'

warn "vim is now pinned. To upgrade later:"
printf '    brew unpin vim && brew upgrade vim && ./bootstrap/native/compile_vim_native.sh\n'
success "Installed and pinned Vim ${VIM_VERSION} for ${RESOLVED_CPU}."
