#!/usr/bin/env bash
# Rebuild the active Homebrew Universal Ctags stable keg for this Apple CPU.
set -euo pipefail

USE_PGO=0
case "${1:-}" in '') ;; --pgo) USE_PGO=1 ;; *) echo "Usage: $0 [--pgo]" >&2; exit 2;; esac
fail() { printf 'Error: %s\n' "$1" >&2; exit 1; }
info() { printf '==> %s\n' "$1"; }
warn() { printf '==> %s\n' "$1" >&2; }
sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
pin_state() {
  local pins
  pins="$(brew list --pinned)" || return 1
  printf '%s\n' "$pins" | grep -Fxq universal-ctags && echo pinned || echo unpinned
}
features() { "$1" --version | sed -n 's/^Optional compiled features: //p' | tr ' ' '\n' | sed '/^$/d' | sort; }
install_names() { otool -L "$1" | sed '1d;s/^[[:space:]]*//;s/[[:space:]].*$//' | sort; }

verify_ctags() {
  local bin="$1" v links d records
  [ -x "$bin" ] || fail "Candidate is not executable: $bin"
  [ "$(lipo -archs "$bin")" = arm64 ] || fail "Candidate is not a thin arm64 binary."
  codesign --verify --strict "$bin" || fail "Candidate signature is invalid."
  v="$($bin --version)"
  printf '%s\n' "$v" | grep -Fq "Universal Ctags $VERSION" || fail "Candidate version is not $VERSION."
  for f in +iconv +xpath +json +yaml +pcre2; do
    printf '%s\n' "$v" | grep -Fq "$f" || fail "Candidate lacks feature $f."
  done
  links="$(otool -L "$bin")"
  for lib in "$JANSSON/lib/libjansson" "$LIBYAML/lib/libyaml" "$PCRE2/lib/libpcre2-8" /usr/lib/libxml2 /usr/lib/libiconv; do
    printf '%s\n' "$links" | grep -Fq "$lib" || fail "Candidate lacks expected linkage: $lib"
  done
  d="$(mktemp -d "${TMPDIR:-/tmp}/ctags-native-smoke.XXXXXX")"
  printf 'int c_native(void) { return 1; }\n' >"$d/a.c"
  printf 'class RubyNative\n  def ruby_native; end\nend\n' >"$d/a.rb"
  printf '{"json_native": {"value": 1}}\n' >"$d/a.json"
  printf 'yaml_native: &yaml_native\n  value: 1\n' >"$d/a.yaml"
  "$bin" --options=NONE --sort=yes --output-format=json --fields=+l -f "$d/tags" "$d/a.c" "$d/a.rb" "$d/a.json" "$d/a.yaml" \
    || { rm -rf "$d"; fail "Parser smoke test failed."; }
  records="$(python3 - "$d/tags" <<'PY'
import json,sys
print('\n'.join(sorted(f"{x['name']}:{x['language']}" for x in map(json.loads,open(sys.argv[1])) if x.get('_type')=='tag' and 'language' in x)))
PY
)"
  rm -rf "$d"
  for record in c_native:C RubyNative:Ruby ruby_native:Ruby json_native:JSON yaml_native:Yaml; do
    printf '%s\n' "$records" | grep -Fxq "$record" || fail "Deterministic parser smoke test lacks $record."
  done
}

command -v brew >/dev/null || fail "Homebrew is required."
[ "$(uname -m)" = arm64 ] || fail "This script supports Apple Silicon only."
BREW="$(brew --prefix)"; OPT="$(brew --prefix universal-ctags 2>/dev/null || true)"
[ -d "$OPT" ] || fail "universal-ctags is not installed."
KEG="$(cd "$OPT" && pwd -P)"
case "$KEG" in "$BREW/Cellar/universal-ctags/"*) ;; *) fail "Active prefix is not a universal-ctags Cellar keg.";; esac
VERSION="$(basename "$KEG")"; TARGET="$KEG/bin/ctags"; FORMULA="$KEG/.brew/universal-ctags.rb"
[ -x "$TARGET" ] && [ -f "$FORMULA" ] || fail "Active binary or formula snapshot is missing."
BASE_FEATURES="$(features "$TARGET")"; BASE_LINKS="$(install_names "$TARGET")"

# Fail closed if Homebrew changes the stable feature/dependency contract.
for contract in 'depends_on "docutils" => :build' 'depends_on "pkgconf" => :build' \
  'depends_on "python@3.14" => :build' 'depends_on "jansson"' 'depends_on "libyaml"' \
  'depends_on "pcre2"' 'uses_from_macos "libxml2"' 'system "./configure", *std_configure_args'; do
  grep -Fq "$contract" "$FORMULA" || fail "Formula contract changed (missing: $contract)."
done
for dep in docutils pkgconf python@3.14 jansson libyaml pcre2 llvm; do
  brew list --versions "$dep" >/dev/null 2>&1 || fail "Homebrew dependency is missing: $dep"
done
JANSSON="$(brew --prefix jansson)"; LIBYAML="$(brew --prefix libyaml)"; PCRE2="$(brew --prefix pcre2)"; PKGCONF="$(brew --prefix pkgconf)"; LLVM="$(brew --prefix llvm)"; CLANG="$LLVM/bin/clang"

BRAND="$(sysctl -n machdep.cpu.brand_string)"
EXPECTED="$(printf '%s\n' "$BRAND" | sed -nE 's/^Apple M([1-9][0-9]*).*/apple-m\1/p')"
[ -n "$EXPECTED" ] || fail "Cannot identify Apple M generation from: $BRAND"
[ -x "$CLANG" ] || fail "Homebrew clang is missing: $CLANG"
"$CLANG" --print-supported-cpus -target arm64-apple-macos 2>&1 | grep -E "^[[:space:]]*$EXPECTED([[:space:]]|$)" >/dev/null \
  || fail "Homebrew clang does not support $EXPECTED (new Apple CPUs require a sufficiently new LLVM toolchain)."
RESOLVED="$("$CLANG" -mcpu=native -### -c -x c /dev/null 2>&1 | sed -n 's/.*"-target-cpu" "\([^"]*\)".*/\1/p' | tail -1)"
[ "$RESOLVED" = "$EXPECTED" ] || fail "clang -mcpu=native resolves to $RESOLVED, but $BRAND requires $EXPECTED."
info "$BRAND validated as clang target $RESOLVED"

SOURCE_URL="$(sed -n 's/^[[:space:]]*url "\([^"]*\)".*/\1/p' "$FORMULA" | head -1)"
SOURCE_SHA="$(sed -n 's/^[[:space:]]*sha256 "\([0-9a-fA-F]*\)".*/\1/p' "$FORMULA" | head -1)"
[ "$SOURCE_URL" = "https://github.com/universal-ctags/ctags/releases/download/v$VERSION/universal-ctags-$VERSION.tar.gz" ] \
  || fail "Formula source URL does not describe stable release $VERSION."
printf '%s' "$SOURCE_SHA" | grep -Eq '^[0-9a-fA-F]{64}$' || fail "Invalid formula SHA-256."

ORIGINAL_PIN="$(pin_state)" || fail "Could not query Homebrew pin state."
CACHE="$(brew --cache)/downloads"; mkdir -p "$CACHE"
ARCHIVE=""
for f in "$CACHE"/*"--universal-ctags-$VERSION.tar.gz" "$CACHE/manual-universal-ctags-$VERSION-$SOURCE_SHA.tar.gz"; do
  [ -f "$f" ] && [ "$(sha256 "$f")" = "$SOURCE_SHA" ] && { ARCHIVE="$f"; break; }
done
if [ -z "$ARCHIVE" ]; then
  ARCHIVE="$CACHE/manual-universal-ctags-$VERSION-$SOURCE_SHA.tar.gz"; PART="$ARCHIVE.partial.$$"
  curl -fL "$SOURCE_URL" -o "$PART" || { rm -f "$PART"; fail "Source download failed."; }
  [ "$(sha256 "$PART")" = "$SOURCE_SHA" ] || { rm -f "$PART"; fail "Downloaded source checksum mismatch."; }
  mv "$PART" "$ARCHIVE"
fi
[ "$(sha256 "$ARCHIVE")" = "$SOURCE_SHA" ] || fail "Source checksum mismatch."

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ctags-native-build.XXXXXX")"; SRC="$ROOT/src"; mkdir "$SRC"
BIN_DIR="$(dirname "$TARGET")"; DIR_MODE="$(stat -f %Lp "$BIN_DIR")"; TARGET_MODE="$(stat -f %Lp "$TARGET")"
STAGE=""; BACKUP=""; PENDING=""; BACKUP_READY=0; COMMITTED=0
cleanup() {
  local status=$? restore
  trap - EXIT; trap '' INT TERM; set +e
  if [ "$COMMITTED" -ne 1 ] && [ "$BACKUP_READY" -eq 1 ] && [ -f "$BACKUP" ]; then
    restore="$BIN_DIR/.ctags.native-restore.$$"
    cp -p "$BACKUP" "$restore" && mv -f "$restore" "$TARGET" && rm -f "$BACKUP" || { warn "Rollback failed; backup retained at $BACKUP"; status=1; }
  fi
  [ -n "$STAGE" ] && rm -f "$STAGE"; [ -n "$PENDING" ] && rm -f "$PENDING"
  chmod "$DIR_MODE" "$BIN_DIR" 2>/dev/null || status=1
  if [ "$COMMITTED" -ne 1 ]; then
    if [ "$ORIGINAL_PIN" = pinned ]; then
      brew pin universal-ctags >/dev/null 2>&1 || true
    else
      brew unpin universal-ctags >/dev/null 2>&1 || true
    fi
    [ "$(pin_state)" = "$ORIGINAL_PIN" ] || status=1
  fi
  rm -rf "$ROOT"; exit "$status"
}
trap cleanup EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
tar -xzf "$ARCHIVE" -C "$SRC" --strip-components=1
[ -x "$SRC/configure" ] || fail "Stable release archive lacks configure."
SDK="$(xcrun --sdk macosx --show-sdk-path)"
mkdir "$ROOT/toolchain"
ln -s "$LLVM/bin/llvm-ar" "$ROOT/toolchain/clang-ar"
ln -s "$LLVM/bin/llvm-ranlib" "$ROOT/toolchain/clang-ranlib"
BUILD_PATH="$ROOT/toolchain:$LLVM/bin:$PKGCONF/bin:/usr/bin:/bin:/usr/sbin:/sbin"
configure_build() {
  local dir="$1" cflags="$2" ldflags="$3"
  mkdir "$dir"
  (cd "$dir" && env -i HOME="$HOME" PATH="$BUILD_PATH" SDKROOT="$SDK" CC="$CLANG" \
    AR="$LLVM/bin/llvm-ar" RANLIB="$LLVM/bin/llvm-ranlib" \
    PKG_CONFIG="$PKGCONF/bin/pkg-config" PKG_CONFIG_PATH="$JANSSON/lib/pkgconfig:$LIBYAML/lib/pkgconfig:$PCRE2/lib/pkgconfig" \
    CPPFLAGS="-I$JANSSON/include -I$LIBYAML/include -I$PCRE2/include -I$SDK/usr/include/libxml2" \
    CFLAGS="$cflags" LDFLAGS="-L$JANSSON/lib -L$LIBYAML/lib -L$PCRE2/lib $ldflags" \
    "$SRC/configure" --prefix="$KEG" --enable-lto \
    && env -i HOME="$HOME" PATH="$BUILD_PATH" SDKROOT="$SDK" make -j"$(sysctl -n hw.logicalcpu)")
}
if [ "$USE_PGO" -eq 1 ]; then
  PROFDATA="$LLVM/bin/llvm-profdata"; CLANG_MAJOR="$("$CLANG" --version | sed -nE '1s/.*version ([0-9]+).*/\1/p')"
  PROF_MAJOR="$($PROFDATA --version | sed -nE '1s/.*version ([0-9]+).*/\1/p')"
  [ -n "$CLANG_MAJOR" ] && [ "$CLANG_MAJOR" = "$PROF_MAJOR" ] || fail "Apple clang/llvm-profdata versions do not match."
  RAW="$ROOT/profiles"; mkdir "$RAW"
  configure_build "$ROOT/pgo-generate" '-O3 -mcpu=native -fprofile-instr-generate' '-fprofile-instr-generate'
  LLVM_PROFILE_FILE="$RAW/ctags-%m-%p.profraw" CTAGS_BENCH_REPETITIONS=3 CTAGS_BENCH_WARMUPS=1 \
    "$(cd "$(dirname "$0")/.." && pwd)/benchmarks/benchmark_ctags_native.sh" "$ROOT/pgo-generate/ctags" pgo-training >/dev/null
  find "$RAW" -name '*.profraw' -print -quit | grep -q . || fail "PGO training produced no profiles."
  "$PROFDATA" merge -o "$ROOT/merged.profdata" "$RAW"/*.profraw
  [ -s "$ROOT/merged.profdata" ] || fail "PGO merged profile is empty."
  configure_build "$ROOT/pgo-use" "-O3 -mcpu=native -fprofile-instr-use=$ROOT/merged.profdata" "-fprofile-instr-use=$ROOT/merged.profdata"
  CANDIDATE="$ROOT/pgo-use/ctags"
else
  configure_build "$ROOT/build" '-O3 -mcpu=native' ''
  CANDIDATE="$ROOT/build/ctags"
fi
verify_ctags "$CANDIDATE"
[ "$(features "$CANDIDATE")" = "$BASE_FEATURES" ] || fail "Candidate optional feature set differs from the bottle."
[ "$(install_names "$CANDIDATE")" = "$BASE_LINKS" ] || fail "Candidate install-name list differs from the bottle."
info "Benchmarking candidate against the currently installed baseline"
CTAGS_BENCH_REPETITIONS="${CTAGS_BENCH_REPETITIONS:-5}" \
  "$(cd "$(dirname "$0")/.." && pwd)/benchmarks/benchmark_ctags_native.sh" "$CANDIDATE" candidate "$TARGET" installed-baseline

# Binary-only, same-filesystem publication. No make install is performed.
chmod u+w "$BIN_DIR"; STAGE="$BIN_DIR/.ctags.native-stage.$$"; PENDING="$BIN_DIR/.ctags.native-backup-pending.$$"; BACKUP="$BIN_DIR/.ctags.native-backup.$$"
cp "$CANDIDATE" "$STAGE"; chmod "$TARGET_MODE" "$STAGE"; verify_ctags "$STAGE"
cp -p "$TARGET" "$PENDING"; mv -f "$PENDING" "$BACKUP"; PENDING=""; BACKUP_READY=1
mv -f "$STAGE" "$TARGET"; STAGE=""; verify_ctags "$TARGET"
[ "$(sha256 "$TARGET")" = "$(sha256 "$CANDIDATE")" ] || fail "Published binary differs from candidate."
brew pin universal-ctags; [ "$(pin_state)" = pinned ] || fail "Could not verify final pin."
chmod "$DIR_MODE" "$BIN_DIR"; trap '' INT TERM
rm -f "$BACKUP" || fail "Could not retire published backup."; BACKUP=""; BACKUP_READY=0; COMMITTED=1
trap - INT TERM
info "Done: Universal Ctags $VERSION, -O3 -mcpu=native --enable-lto$([ "$USE_PGO" -eq 1 ] && printf ' + PGO')"
