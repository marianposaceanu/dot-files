#!/usr/bin/env bash
# Build the active Homebrew ripgrep version for this Apple Silicon CPU.
#
# The build uses ripgrep's upstream release-lto profile (fat LTO, one codegen
# unit, panic=abort, stripped symbols) plus Rust's target-cpu=native. It keeps
# Homebrew's PCRE2 feature and shared-library linkage, verifies the candidate,
# atomically replaces only the active keg's rg binary, and pins the formula.
#
# Upgrade path:
#   brew unpin ripgrep && brew upgrade ripgrep \
#     && ./bootstrap/compile_ripgrep_native.sh

set -euo pipefail

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

info() {
  printf '==> %s\n' "$1"
}

warn() {
  printf '==> %s\n' "$1" >&2
}

sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

ripgrep_pin_state() {
  local pinned
  pinned="$(brew list --pinned)" || return 2
  if printf '%s\n' "$pinned" | grep -Fxq ripgrep; then
    printf 'pinned\n'
  else
    printf 'unpinned\n'
  fi
}

verify_ripgrep() {
  local candidate="$1"
  local version_output linkage test_dir output

  [ -x "$candidate" ] || fail "Candidate is not executable: $candidate"
  [ "$(lipo -archs "$candidate")" = "arm64" ] \
    || fail "Candidate is not a thin arm64 binary: $candidate"
  codesign --verify --strict "$candidate" \
    || fail "Candidate code signature is invalid: $candidate"

  version_output="$("$candidate" --version)"
  printf '%s\n' "$version_output" | grep -Fxq "ripgrep $RIPGREP_VERSION" \
    || fail "Candidate does not report ripgrep $RIPGREP_VERSION."
  for feature in 'features:+pcre2' 'simd(compile):+NEON' \
    'simd(runtime):+NEON' 'JIT is available'; do
    printf '%s\n' "$version_output" | grep -Fq "$feature" \
      || fail "Candidate is missing expected capability: $feature"
  done

  linkage="$(otool -L "$candidate")"
  printf '%s\n' "$linkage" | grep -Fq "$PCRE2_PREFIX/lib/libpcre2-8" \
    || fail "Candidate is not linked to Homebrew PCRE2."

  test_dir="$(mktemp -d "${TMPDIR:-/tmp}/ripgrep-native-test.XXXXXX")"
  mkdir -p "$test_dir/src"
  printf 'alpha NEEDLE omega\nrequest_id=0123456789abcdef;\n' \
    >"$test_dir/src/example.rs"
  printf 'alpha only\n' >"$test_dir/example.txt"

  output="$("$candidate" --no-config -l NEEDLE "$test_dir")"
  [ "$output" = "$test_dir/src/example.rs" ] \
    || { rm -rf "$test_dir"; fail "Candidate literal-search smoke test failed."; }
  output="$("$candidate" --no-config -F -l 'alpha NEEDLE' "$test_dir")"
  [ "$output" = "$test_dir/src/example.rs" ] \
    || { rm -rf "$test_dir"; fail "Candidate fixed-string smoke test failed."; }
  output="$("$candidate" --no-config -t rust -l NEEDLE "$test_dir")"
  [ "$output" = "$test_dir/src/example.rs" ] \
    || { rm -rf "$test_dir"; fail "Candidate file-type smoke test failed."; }
  output="$("$candidate" --no-config --pcre2 -o \
    '(?<=request_id=)[a-f0-9]{16}(?=;)' "$test_dir/src/example.rs")"
  [ "$output" = "0123456789abcdef" ] \
    || { rm -rf "$test_dir"; fail "Candidate PCRE2/JIT smoke test failed."; }
  rm -rf "$test_dir"
}

command -v brew >/dev/null 2>&1 || fail "Homebrew is not installed."
[ "$(uname -m)" = "arm64" ] \
  || fail "This script only supports native Apple Silicon."

BREW_PREFIX="$(brew --prefix)"
OPT_PREFIX="$(brew --prefix ripgrep 2>/dev/null || true)"
[ -d "$OPT_PREFIX" ] || fail "ripgrep is not installed via Homebrew."
KEG="$(cd "$OPT_PREFIX" && pwd -P)"
case "$KEG" in
  "$BREW_PREFIX/Cellar/ripgrep/"*) ;;
  *) fail "Homebrew ripgrep prefix does not resolve to a Cellar keg: $KEG" ;;
esac

RIPGREP_VERSION="$(basename "$KEG")"
TARGET="$KEG/bin/rg"
FORMULA="$KEG/.brew/ripgrep.rb"
[ -x "$TARGET" ] || fail "Active ripgrep binary is missing: $TARGET"
[ -f "$FORMULA" ] || fail "Installed formula snapshot is missing: $FORMULA"

for text in 'depends_on "rust" => :build' 'depends_on "pcre2"' \
  'std_cargo_args(features: "pcre2")'; do
  grep -Fq -- "$text" "$FORMULA" \
    || fail "Installed ripgrep formula changed (missing: $text). Update this script first."
done

for dependency in rust pcre2 pkgconf; do
  brew list --versions "$dependency" >/dev/null 2>&1 \
    || fail "Homebrew dependency '$dependency' is not installed."
done

RUST_PREFIX="$(brew --prefix rust)"
PCRE2_PREFIX="$(brew --prefix pcre2)"
PKGCONF_PREFIX="$(brew --prefix pkgconf)"
CARGO="$RUST_PREFIX/bin/cargo"
RUSTC="$RUST_PREFIX/bin/rustc"
[ -x "$CARGO" ] || fail "Cargo is missing: $CARGO"
[ -x "$RUSTC" ] || fail "rustc is missing: $RUSTC"

CPU_BRAND="$(sysctl -n machdep.cpu.brand_string)"
EXPECTED_CPU="$(printf '%s\n' "$CPU_BRAND" \
  | sed -nE 's/^Apple M([0-9]+).*/apple-m\1/p')"
[ -n "$EXPECTED_CPU" ] \
  || fail "Could not determine the Apple M-series generation from: $CPU_BRAND"
RESOLVED_CPU="$($RUSTC --print target-cpus | sed -n \
  's/^[[:space:]]*native[[:space:]]*-.*currently \([^)]*\)).*/\1/p' | head -1)"
printf '%s\n' "$RESOLVED_CPU" | grep -Eq '^apple-m[0-9]+$' \
  || fail "Could not resolve Rust target-cpu=native to an Apple CPU: $RESOLVED_CPU"
[ "$RESOLVED_CPU" = "$EXPECTED_CPU" ] \
  || fail "Rust resolves native to $RESOLVED_CPU, but $CPU_BRAND requires $EXPECTED_CPU."
$RUSTC --print cfg -C "target-cpu=$RESOLVED_CPU" >/dev/null \
  || fail "rustc does not accept the resolved CPU target: $RESOLVED_CPU"
info "$CPU_BRAND validated as Rust target $RESOLVED_CPU"

SOURCE_URL="$(sed -n 's/^[[:space:]]*url "\([^"]*\)".*/\1/p' "$FORMULA" | head -1)"
SOURCE_SHA256="$(sed -n 's/^[[:space:]]*sha256 "\([0-9a-fA-F]*\)".*/\1/p' "$FORMULA" | head -1)"
printf '%s' "$SOURCE_URL" | grep -Fq "/tags/$RIPGREP_VERSION.tar.gz" \
  || fail "Formula source URL does not match ripgrep $RIPGREP_VERSION: $SOURCE_URL"
printf '%s' "$SOURCE_SHA256" | grep -Eq '^[0-9a-fA-F]{64}$' \
  || fail "Formula source SHA-256 is missing or invalid."

ORIGINAL_PIN_STATE="$(ripgrep_pin_state)" \
  || fail "Could not determine ripgrep's Homebrew pin state."

DOWNLOADS_DIR="$(brew --cache)/downloads"
mkdir -p "$DOWNLOADS_DIR"
SOURCE_TARBALL=""
for candidate in "$DOWNLOADS_DIR"/*"--ripgrep-${RIPGREP_VERSION}.tar.gz" \
  "$DOWNLOADS_DIR/manual-ripgrep-${RIPGREP_VERSION}-${SOURCE_SHA256}.tar.gz"; do
  [ -f "$candidate" ] || continue
  if [ "$(sha256 "$candidate")" = "$SOURCE_SHA256" ]; then
    SOURCE_TARBALL="$candidate"
    break
  fi
  warn "Ignoring cached source with the wrong checksum: $candidate"
done

if [ -z "$SOURCE_TARBALL" ]; then
  SOURCE_TARBALL="$DOWNLOADS_DIR/manual-ripgrep-${RIPGREP_VERSION}-${SOURCE_SHA256}.tar.gz"
  PARTIAL_TARBALL="${SOURCE_TARBALL}.partial.$$"
  info "Downloading exact ripgrep $RIPGREP_VERSION source"
  curl -fL "$SOURCE_URL" -o "$PARTIAL_TARBALL"
  if [ "$(sha256 "$PARTIAL_TARBALL")" != "$SOURCE_SHA256" ]; then
    rm -f "$PARTIAL_TARBALL"
    fail "Downloaded ripgrep source failed SHA-256 verification."
  fi
  mv "$PARTIAL_TARBALL" "$SOURCE_TARBALL"
fi
[ "$(sha256 "$SOURCE_TARBALL")" = "$SOURCE_SHA256" ] \
  || fail "ripgrep source archive failed SHA-256 verification."
info "Verified source: $(basename "$SOURCE_TARBALL")"

BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ripgrep-native-build.XXXXXX")"
CELLAR_BIN="$(dirname "$TARGET")"
CELLAR_BIN_MODE="$(stat -f '%Lp' "$CELLAR_BIN")"
TARGET_MODE="$(stat -f '%Lp' "$TARGET")"
STAGED_TARGET=""
BACKUP_PENDING=""
BACKUP_TARGET=""
BACKUP_READY=0
COMMITTED=0

cleanup() {
  local status="$?" restore_target current_pin_state
  trap - EXIT
  trap '' INT TERM
  set +e
  if [ "$COMMITTED" -ne 1 ] && [ "$BACKUP_READY" -eq 1 ] \
    && [ -n "$BACKUP_TARGET" ] \
    && [ -f "$BACKUP_TARGET" ]; then
    warn "Restoring the previous ripgrep binary after failure"
    restore_target="$CELLAR_BIN/.rg.native-restore.$$"
    if cp -p "$BACKUP_TARGET" "$restore_target" \
      && mv -f "$restore_target" "$TARGET"; then
      rm -f "$BACKUP_TARGET"
      BACKUP_TARGET=""
      BACKUP_READY=0
    else
      rm -f "$restore_target"
      warn "Could not restore $TARGET; backup retained at $BACKUP_TARGET"
      status=1
    fi
  fi
  [ -n "$STAGED_TARGET" ] && rm -f "$STAGED_TARGET"
  [ -n "$BACKUP_PENDING" ] && rm -f "$BACKUP_PENDING"
  if [ "$BACKUP_READY" -eq 0 ] && [ -n "$BACKUP_TARGET" ]; then
    rm -f "$BACKUP_TARGET"
  fi
  if ! chmod "$CELLAR_BIN_MODE" "$CELLAR_BIN" 2>/dev/null; then
    warn "Could not restore directory mode $CELLAR_BIN_MODE on $CELLAR_BIN"
    status=1
  fi
  if [ "$COMMITTED" -ne 1 ]; then
    if [ "$ORIGINAL_PIN_STATE" = "pinned" ]; then
      brew pin ripgrep >/dev/null 2>&1 || true
    else
      brew unpin ripgrep >/dev/null 2>&1 || true
    fi
    current_pin_state="$(ripgrep_pin_state)"
    if [ "$?" -ne 0 ]; then
      warn "Could not verify ripgrep's restored pin state."
      status=1
    elif [ "$current_pin_state" != "$ORIGINAL_PIN_STATE" ]; then
      warn "Could not restore ripgrep's original pin state."
      status=1
    fi
  fi
  rm -rf "$BUILD_DIR"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

info "Extracting source"
tar -xzf "$SOURCE_TARBALL" -C "$BUILD_DIR" --strip-components=1
grep -Fq '[profile.release-lto]' "$BUILD_DIR/Cargo.toml" \
  || fail "Upstream release-lto profile is missing."
for setting in 'lto = "fat"' 'codegen-units = 1' 'panic = "abort"'; do
  grep -Fq "$setting" "$BUILD_DIR/Cargo.toml" \
    || fail "Upstream release-lto profile changed (missing: $setting)."
done

BUILD_PATH="$RUST_PREFIX/bin:$PKGCONF_PREFIX/bin:/usr/bin:/bin:/usr/sbin:/sbin"
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
info "Building ripgrep with release-lto and -C target-cpu=native"
env -i \
  HOME="$HOME" \
  TMPDIR="${TMPDIR:-/tmp}" \
  PATH="$BUILD_PATH" \
  SDKROOT="$SDKROOT" \
  CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}" \
  PKG_CONFIG="$PKGCONF_PREFIX/bin/pkg-config" \
  PKG_CONFIG_PATH="$PCRE2_PREFIX/lib/pkgconfig" \
  RUSTFLAGS="-C target-cpu=native" \
  "$CARGO" build \
    --manifest-path "$BUILD_DIR/Cargo.toml" \
    --target-dir "$BUILD_DIR/target" \
    --locked \
    --profile release-lto \
    --features pcre2 \
    --target aarch64-apple-darwin

CANDIDATE="$BUILD_DIR/target/aarch64-apple-darwin/release-lto/rg"
info "Verifying candidate before touching the Cellar"
verify_ripgrep "$CANDIDATE"

STAGED_TARGET="$CELLAR_BIN/.rg.native-stage.$$"
BACKUP_PENDING="$CELLAR_BIN/.rg.native-backup-pending.$$"
BACKUP_TARGET="$CELLAR_BIN/.rg.native-backup.$$"
chmod u+w "$CELLAR_BIN"
cp "$CANDIDATE" "$STAGED_TARGET"
chmod "$TARGET_MODE" "$STAGED_TARGET"
verify_ripgrep "$STAGED_TARGET"
cp -p "$TARGET" "$BACKUP_PENDING"
mv -f "$BACKUP_PENDING" "$BACKUP_TARGET"
BACKUP_PENDING=""
BACKUP_READY=1
info "Atomically replacing $TARGET"
mv -f "$STAGED_TARGET" "$TARGET"
STAGED_TARGET=""

verify_ripgrep "$TARGET"
[ "$(sha256 "$TARGET")" = "$(sha256 "$CANDIDATE")" ] \
  || fail "Installed ripgrep does not match the verified candidate."

info "Pinning ripgrep so Homebrew does not overwrite the native build"
brew pin ripgrep || fail "Could not pin the verified native ripgrep build."
[ "$(ripgrep_pin_state)" = "pinned" ] \
  || fail "Could not verify ripgrep's pinned state."

chmod "$CELLAR_BIN_MODE" "$CELLAR_BIN"
trap '' INT TERM
rm -f "$BACKUP_TARGET" \
  || fail "Could not remove the completed backup during finalization."
BACKUP_TARGET=""
BACKUP_READY=0
COMMITTED=1
trap - INT TERM

info "Done"
"$TARGET" --version
printf '\nNative target: %s\n' "$RESOLVED_CPU"
printf 'Rust profile: release-lto; RUSTFLAGS: -C target-cpu=native\n'
printf 'Upgrade later with:\n'
printf '  brew unpin ripgrep && brew upgrade ripgrep && ./bootstrap/compile_ripgrep_native.sh\n'
