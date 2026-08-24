#!/usr/bin/env bash
# bootstrap/native/compile_git_native.sh
# Rebuild the active Homebrew Git executable for the local Apple CPU.

set -euo pipefail

USE_PGO=0
case "${1:-}" in
  "") ;;
  --pgo) USE_PGO=1 ;;
  *) printf 'Usage: %s [--pgo]\n' "$0" >&2; exit 2 ;;
esac

fail() {
  printf '╭─ NATIVE GIT BUILD FAILED\n' >&2
  printf '╰─ %s\n' "$1" >&2
  exit 1
}

info() {
  printf '• %s\n' "$1"
}

warn() {
  printf '! %s\n' "$1" >&2
}

complete() {
  printf '\n╭─ NATIVE GIT BUILD COMPLETE\n'
  printf '╰─ %s\n' "$1"
}

sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

pin_state() {
  local pins
  pins="$(brew list --pinned)" || return 1
  if printf '%s\n' "$pins" | grep -Fxq git; then
    printf 'pinned\n'
  else
    printf 'unpinned\n'
  fi
}

build_options() {
  "$1" version --build-options | sed '/^built from commit:/d'
}

install_names() {
  otool -L "$1" \
    | sed '1d;s/^[[:space:]]*//;s/[[:space:]].*$//' \
    | sort
}

rpaths() {
  otool -l "$1" | awk '
    $1 == "cmd" { is_rpath = ($2 == "LC_RPATH") }
    is_rpath && $1 == "path" { print $2 }
  ' | sort
}

require_formula_text() {
  grep -Fq -- "$1" "$FORMULA" \
    || fail "Installed Git formula changed (missing: $1). Update this script before rebuilding."
}

verify_git() {
  local candidate="$1"
  local output test_dir test_home

  [ -x "$candidate" ] || fail "Candidate is not executable: $candidate"
  [ "$(lipo -archs "$candidate")" = arm64 ] \
    || fail "Candidate is not a thin arm64 binary: $candidate"
  codesign --verify --strict "$candidate" \
    || fail "Candidate code signature is invalid: $candidate"
  [ "$("$candidate" --version)" = "git version $GIT_VERSION" ] \
    || fail "Candidate does not report Git $GIT_VERSION."

  output="$("$candidate" version --build-options)"
  printf '%s\n' "$output" | grep -Fq 'sizeof-long: 8' \
    || fail "Candidate reports unexpected build options."
  otool -L "$candidate" | grep -Fq "$PCRE2_PREFIX/lib/libpcre2-8" \
    || fail "Candidate is not linked to Homebrew PCRE2."
  if install_names "$candidate" | grep -Fq "$KEG"; then
    fail "Candidate contains a Git Cellar install name."
  fi
  if rpaths "$candidate" | grep -Fq "$KEG"; then
    fail "Candidate contains a Git Cellar runtime path."
  fi

  [ "$("$candidate" --exec-path)" = "$OPT_PREFIX/libexec/git-core" ] \
    && [ "$("$candidate" --html-path)" = "$OPT_PREFIX/share/doc/git-doc" ] \
    && [ "$("$candidate" --man-path)" = "$OPT_PREFIX/share/man" ] \
    || fail "Candidate installed runtime paths do not match the stable opt prefix."

  test_dir="$(mktemp -d "$ROOT/smoke.XXXXXX")"
  test_home="$test_dir/home"
  mkdir -p "$test_home"
  HOME="$test_home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    "$candidate" init -q --initial-branch=main "$test_dir/repo"
  HOME="$test_home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    "$candidate" -C "$test_dir/repo" config user.name Test
  HOME="$test_home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    "$candidate" -C "$test_dir/repo" config user.email x@y.invalid
  printf 'needle\n' >"$test_dir/repo/a"
  HOME="$test_home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    "$candidate" -C "$test_dir/repo" add a
  HOME="$test_home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    "$candidate" -C "$test_dir/repo" commit -qm one
  HOME="$test_home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    "$candidate" -C "$test_dir/repo" branch side
  printf 'two\n' >>"$test_dir/repo/a"
  HOME="$test_home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    "$candidate" -C "$test_dir/repo" commit -qam two
  HOME="$test_home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    "$candidate" -C "$test_dir/repo" merge -q side
  HOME="$test_home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    "$candidate" -C "$test_dir/repo" grep needle >/dev/null
  HOME="$test_home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    "$candidate" -C "$test_dir/repo" grep -P 'need\w+' >/dev/null
  HOME="$test_home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    "$candidate" -C "$test_dir/repo" fsck --no-progress
  HOME="$test_home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    "$candidate" -C "$test_dir/repo" gc --quiet
  HOME="$test_home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    "$candidate" -C "$test_dir/repo" bundle create "$test_dir/bundle" --all
  HOME="$test_home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    "$candidate" -c protocol.file.allow=always clone -q \
      "$test_dir/repo" "$test_dir/clone"
  rm -rf "$test_dir"
}

build_git() {
  local build_dir="$1"
  local profile_flags="$2"

  mkdir "$build_dir"
  cp -R "$SOURCE_DIR/." "$build_dir/"
  env -i HOME="$HOME" PATH="$BUILD_PATH" SDKROOT="$SDKROOT" \
    make -C "$build_dir" clean >/dev/null
  env -i HOME="$HOME" PATH="$BUILD_PATH" SDKROOT="$SDKROOT" \
    PKG_CONFIG="$PKGCONF_PREFIX/bin/pkg-config" \
    make -C "$build_dir" -j"$(sysctl -n hw.ncpu)" git \
      "${MAKE_ARGS[@]}" \
      "CFLAGS=-O3 -mcpu=native -flto $profile_flags"
}

printf '╭─ NATIVE GIT BUILD\n'
printf '╰─ Rebuilding the active Homebrew binary for this Apple CPU\n'

command -v brew >/dev/null 2>&1 || fail "Homebrew is required."
[ "$(uname -m)" = arm64 ] || fail "This script supports native Apple Silicon only."

BREW_PREFIX="$(brew --prefix)"
OPT_PREFIX="$(brew --prefix git 2>/dev/null || true)"
[ -d "$OPT_PREFIX" ] || fail "Git is not installed via Homebrew."
KEG="$(cd "$OPT_PREFIX" && pwd -P)"
case "$KEG" in
  "$BREW_PREFIX/Cellar/git/"*) ;;
  *) fail "Homebrew Git prefix does not resolve to a Git Cellar keg: $KEG" ;;
esac

FORMULA="$KEG/.brew/git.rb"
TARGET="$KEG/bin/git"
[ -f "$FORMULA" ] || fail "Installed formula snapshot is missing: $FORMULA"
[ -x "$TARGET" ] || fail "Active Git binary is missing: $TARGET"
GIT_VERSION="$("$TARGET" --version | sed -n 's/^git version //p')"
[ -n "$GIT_VERSION" ] || fail "Could not determine the active Git version."

# Fail closed if Homebrew changes the build or runtime-path contract.
for contract in \
  'depends_on "gettext" => :build' \
  'depends_on "pkgconf" => :build' \
  'depends_on "pcre2"' \
  'uses_from_macos "curl"' \
  'uses_from_macos "expat"' \
  'ENV["NO_FINK"] = "1"' \
  'ENV["NO_DARWIN_PORTS"] = "1"' \
  'ENV["USE_LIBPCRE2"] = "1"' \
  'ENV["LIBPCREDIR"] = formula_opt_prefix("pcre2")' \
  'NO_TCLTK=1' \
  'NO_RUST=1' \
  'NO_OPENSSL=1' \
  'APPLE_COMMON_CRYPTO=1' \
  'inreplace "Makefile", /(-DFALLBACK_RUNTIME_PREFIX=")[^"]+/, "\\1#{opt_prefix}"' \
  'system "make", "install", *args'; do
  require_formula_text "$contract"
done

SOURCE_URL="$(sed -n 's/^[[:space:]]*url "\([^"]*\)".*/\1/p' "$FORMULA" | head -1)"
SOURCE_SHA256="$(sed -n 's/^[[:space:]]*sha256 "\([0-9a-fA-F]*\)".*/\1/p' "$FORMULA" | head -1)"
[ "$(basename "$SOURCE_URL")" = "git-$GIT_VERSION.tar.xz" ] \
  || fail "Formula source URL does not describe active Git $GIT_VERSION: $SOURCE_URL"
printf '%s' "$SOURCE_SHA256" | grep -Eq '^[0-9a-fA-F]{64}$' \
  || fail "Formula source SHA-256 is missing or invalid."

for dependency in llvm pcre2 gettext pkgconf; do
  brew list --versions "$dependency" >/dev/null 2>&1 \
    || fail "Homebrew dependency is missing: $dependency"
done

LLVM_PREFIX="$(brew --prefix llvm)"
PCRE2_PREFIX="$(brew --prefix pcre2)"
GETTEXT_PREFIX="$(brew --prefix gettext)"
PKGCONF_PREFIX="$(brew --prefix pkgconf)"
CLANG="$LLVM_PREFIX/bin/clang"
LLVM_PROFDATA="$LLVM_PREFIX/bin/llvm-profdata"
[ -x "$CLANG" ] || fail "Homebrew clang is missing: $CLANG"

CPU_BRAND="$(sysctl -n machdep.cpu.brand_string)"
EXPECTED_CPU="$(printf '%s\n' "$CPU_BRAND" \
  | sed -nE 's/^Apple M([1-9][0-9]*).*/apple-m\1/p')"
[ -n "$EXPECTED_CPU" ] || fail "Unrecognized Apple CPU: $CPU_BRAND"
"$CLANG" --print-supported-cpus -target arm64-apple-macos 2>&1 \
  | grep -E "^[[:space:]]*$EXPECTED_CPU([[:space:]]|$)" >/dev/null \
  || fail "Homebrew clang does not support $EXPECTED_CPU."
RESOLVED_CPU="$("$CLANG" -mcpu=native -### -c -x c /dev/null 2>&1 \
  | sed -n 's/.*"-target-cpu" "\([^"]*\)".*/\1/p' | tail -1)"
[ "$RESOLVED_CPU" = "$EXPECTED_CPU" ] \
  || fail "clang resolves native as $RESOLVED_CPU, but $CPU_BRAND requires $EXPECTED_CPU."
info "$CPU_BRAND validated as clang target $RESOLVED_CPU"

if [ "$USE_PGO" -eq 1 ]; then
  [ -x "$LLVM_PROFDATA" ] || fail "Homebrew llvm-profdata is missing."
  CLANG_MAJOR="$("$CLANG" --version | sed -nE '1s/.*version ([0-9]+).*/\1/p')"
  PROFDATA_MAJOR="$("$LLVM_PROFDATA" --version \
    | sed -nE '1s/.*version ([0-9]+).*/\1/p')"
  [ -n "$CLANG_MAJOR" ] && [ "$CLANG_MAJOR" = "$PROFDATA_MAJOR" ] \
    || fail "Homebrew clang and llvm-profdata versions do not match."
fi

BASE_BUILD_OPTIONS="$(build_options "$TARGET")"
BASE_INSTALL_NAMES="$(install_names "$TARGET")"
BASE_RPATHS="$(rpaths "$TARGET")"
ORIGINAL_PIN_STATE="$(pin_state)" || fail "Could not query Git's Homebrew pin state."

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/git-native-build.XXXXXX")"
SOURCE_ARCHIVE="$ROOT/git-$GIT_VERSION.tar.xz"
SOURCE_DIR="$ROOT/source"
BIN_DIR="$(dirname "$TARGET")"
BIN_DIR_MODE="$(stat -f %Lp "$BIN_DIR")"
TARGET_MODE="$(stat -f %Lp "$TARGET")"
STAGED_TARGET=""
BACKUP_PENDING=""
BACKUP_TARGET=""
BACKUP_READY=0
COMMITTED=0

cleanup() {
  local status=$? restore_target current_pin
  trap - EXIT
  trap '' INT TERM
  set +e

  if [ "$COMMITTED" -ne 1 ] && [ "$BACKUP_READY" -eq 1 ] \
    && [ -f "$BACKUP_TARGET" ]; then
    warn "Restoring the previous Git binary after failure"
    restore_target="$BIN_DIR/.git.native-restore.$$"
    if cp -p "$BACKUP_TARGET" "$restore_target" \
      && mv -f "$restore_target" "$TARGET"; then
      rm -f "$BACKUP_TARGET"
      BACKUP_TARGET=""
      BACKUP_READY=0
    else
      rm -f "$restore_target"
      warn "Rollback failed; backup retained at $BACKUP_TARGET"
      status=1
    fi
  fi

  [ -n "$STAGED_TARGET" ] && rm -f "$STAGED_TARGET"
  [ -n "$BACKUP_PENDING" ] && rm -f "$BACKUP_PENDING"
  chmod "$BIN_DIR_MODE" "$BIN_DIR" 2>/dev/null \
    || { warn "Could not restore the Git bin directory mode."; status=1; }

  if [ "$COMMITTED" -ne 1 ]; then
    if [ "$ORIGINAL_PIN_STATE" = pinned ]; then
      brew pin git >/dev/null 2>&1 || true
    else
      brew unpin git >/dev/null 2>&1 || true
    fi
    current_pin="$(pin_state)"
    if [ "$?" -ne 0 ] || [ "$current_pin" != "$ORIGINAL_PIN_STATE" ]; then
      warn "Could not restore Git's original Homebrew pin state."
      status=1
    fi
  fi

  rm -rf "$ROOT"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

info "Downloading exact Git $GIT_VERSION source"
curl -fL "$SOURCE_URL" -o "$SOURCE_ARCHIVE"
[ "$(sha256 "$SOURCE_ARCHIVE")" = "$SOURCE_SHA256" ] \
  || fail "Downloaded Git source failed SHA-256 verification."
mkdir "$SOURCE_DIR"
tar -xJf "$SOURCE_ARCHIVE" -C "$SOURCE_DIR" --strip-components=1

# Homebrew requires this compiled path to use the stable opt prefix, never Cellar.
grep -Eq -- '-DFALLBACK_RUNTIME_PREFIX="[^"]+' "$SOURCE_DIR/Makefile" \
  || fail "Git Makefile fallback-runtime definition changed."
perl -pi -e \
  's!(-DFALLBACK_RUNTIME_PREFIX=")[^"]+!${1}/opt/homebrew/opt/git!' \
  "$SOURCE_DIR/Makefile"
grep -Fq -- '-DFALLBACK_RUNTIME_PREFIX="/opt/homebrew/opt/git' "$SOURCE_DIR/Makefile" \
  || fail "Could not apply Homebrew's stable fallback runtime prefix."

SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
BUILD_PATH="$LLVM_PREFIX/bin:$PKGCONF_PREFIX/bin:/usr/bin:/bin:/usr/sbin:/sbin"
MAKE_ARGS=(
  "prefix=$KEG"
  "sysconfdir=$BREW_PREFIX/etc"
  "CC=$CLANG"
  "AR=$LLVM_PREFIX/bin/llvm-ar"
  "RANLIB=$LLVM_PREFIX/bin/llvm-ranlib"
  'LDFLAGS=-flto'
  NO_TCLTK=1
  NO_RUST=1
  NO_OPENSSL=1
  APPLE_COMMON_CRYPTO=1
  USE_LIBPCRE2=1
  USE_HOMEBREW_LIBICONV=
  NO_FINK=1
  NO_DARWIN_PORTS=1
  "LIBPCREDIR=$PCRE2_PREFIX"
  "LIBINTL=$GETTEXT_PREFIX/lib/libintl.dylib"
  "CURLDIR=$SDKROOT/usr"
  "PERL_PATH=/usr/bin/perl"
  "SHELL_PATH=/bin/sh"
)

if [ "$USE_PGO" -eq 1 ]; then
  PROFILE_DIR="$ROOT/profiles"
  mkdir "$PROFILE_DIR"
  build_git "$ROOT/pgo-generate" "-fprofile-generate=$PROFILE_DIR"
  LLVM_PROFILE_FILE="$PROFILE_DIR/git-%m-%p.profraw" \
    GIT_BENCH_REPETITIONS=3 \
    "$(dirname "$0")/../../benchmarks/benchmark_git_native.sh" \
      "$ROOT/pgo-generate/git" pgo-training >/dev/null
  find "$PROFILE_DIR" -name '*.profraw' -size +0 -print -quit | grep -q . \
    || fail "PGO training produced no raw profile."
  "$LLVM_PROFDATA" merge -o "$ROOT/merged.profdata" "$PROFILE_DIR"/*.profraw
  [ -s "$ROOT/merged.profdata" ] || fail "Merged PGO profile is empty."
  build_git "$ROOT/pgo-use" "-fprofile-use=$ROOT/merged.profdata"
  CANDIDATE="$ROOT/pgo-use/git"
else
  build_git "$ROOT/build" ""
  CANDIDATE="$ROOT/build/git"
fi

info "Verifying candidate"
verify_git "$CANDIDATE"
[ "$(build_options "$CANDIDATE")" = "$BASE_BUILD_OPTIONS" ] \
  || fail "Candidate build options differ from the Homebrew bottle."
[ "$(install_names "$CANDIDATE")" = "$BASE_INSTALL_NAMES" ] \
  || fail "Candidate install names differ from the Homebrew bottle."
[ "$(rpaths "$CANDIDATE")" = "$BASE_RPATHS" ] \
  || fail "Candidate runtime paths differ from the Homebrew bottle."

info "Benchmarking candidate against the currently installed baseline"
GIT_BENCH_REPETITIONS="${GIT_BENCH_REPETITIONS:-5}" \
  "$(dirname "$0")/../../benchmarks/benchmark_git_native.sh" \
    "$CANDIDATE" "$TARGET"

# Publish only after verification and benchmarking. All renames stay in the keg.
chmod u+w "$BIN_DIR"
STAGED_TARGET="$BIN_DIR/.git.native-stage.$$"
BACKUP_PENDING="$BIN_DIR/.git.native-backup-pending.$$"
BACKUP_TARGET="$BIN_DIR/.git.native-backup.$$"
cp "$CANDIDATE" "$STAGED_TARGET"
chmod "$TARGET_MODE" "$STAGED_TARGET"
verify_git "$STAGED_TARGET"
cp -p "$TARGET" "$BACKUP_PENDING"
mv -f "$BACKUP_PENDING" "$BACKUP_TARGET"
BACKUP_PENDING=""
BACKUP_READY=1
mv -f "$STAGED_TARGET" "$TARGET"
STAGED_TARGET=""
verify_git "$TARGET"
[ "$(sha256 "$TARGET")" = "$(sha256 "$CANDIDATE")" ] \
  || fail "Published Git binary differs from the candidate."

brew pin git || fail "Could not pin the verified Git build."
[ "$(pin_state)" = pinned ] || fail "Could not verify the final Git pin."
chmod "$BIN_DIR_MODE" "$BIN_DIR"
trap '' INT TERM
rm -f "$BACKUP_TARGET" || fail "Could not retire the published backup."
BACKUP_TARGET=""
BACKUP_READY=0
COMMITTED=1
trap - INT TERM

complete "Git $GIT_VERSION installed and pinned ($CPU_BRAND)$([ "$USE_PGO" -eq 1 ] && printf ' + PGO')"
