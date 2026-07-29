#!/usr/bin/env bash
# Rebuild only Homebrew Git 2.55.0's main executable for the local Apple CPU.
set -euo pipefail
PGO=0; case "${1:-}" in "") ;; --pgo) PGO=1;; *) echo "Usage: $0 [--pgo]" >&2; exit 2;; esac
fail(){ echo "Error: $*" >&2; exit 1; }; info(){ echo "==> $*"; }; warn(){ echo "==> $*" >&2; }
sum(){ shasum -a 256 "$1" | awk '{print $1}'; }
pin_state(){ local p; p="$(brew list --pinned)" || return 1; printf '%s\n' "$p" | grep -Fxq git && echo pinned || echo unpinned; }
build_options(){ "$1" version --build-options | sed '/^built from commit:/d'; }
install_names(){ otool -L "$1" | sed '1d;s/^[[:space:]]*//;s/[[:space:]].*$//' | sort; }
rpaths(){ otool -l "$1" | awk '$1=="cmd"{r=($2=="LC_RPATH")} r&&$1=="path"{print $2}' | sort; }
command -v brew >/dev/null || fail 'Homebrew is required'
[ "$(uname -m)" = arm64 ] || fail 'native Apple Silicon is required'
BREW="$(brew --prefix)"; OPT="$(brew --prefix git)"; KEG="$(cd "$OPT" && pwd -P)"
case "$KEG" in "$BREW/Cellar/git/2.55.0") ;; *) fail "active keg must be Homebrew git 2.55.0: $KEG";; esac
FORMULA="$KEG/.brew/git.rb"; TARGET="$KEG/bin/git"; [ -f "$FORMULA" ] && [ -x "$TARGET" ] || fail 'incomplete active keg'
BASE_OPTIONS="$(build_options "$TARGET")"; BASE_LINKS="$(install_names "$TARGET")"; BASE_RPATHS="$(rpaths "$TARGET")"
URL='https://mirrors.edge.kernel.org/pub/software/scm/git/git-2.55.0.tar.xz'
SHA='457fdb04dc8728e007d4688695e6912e6f680727920f2a40bf11eacc17505357'
grep -Fq "url \"$URL\"" "$FORMULA" && grep -Fq "sha256 \"$SHA\"" "$FORMULA" || fail 'installed formula source contract changed'
for x in NO_TCLTK NO_RUST NO_OPENSSL APPLE_COMMON_CRYPTO FALLBACK_RUNTIME_PREFIX USE_LIBPCRE2 NO_FINK NO_DARWIN_PORTS; do grep -Fq "$x" "$FORMULA" || fail "formula contract changed: $x"; done
LLVM="$(brew --prefix llvm)"; CC="$LLVM/bin/clang"; PD="$LLVM/bin/llvm-profdata"
PCRE="$(brew --prefix pcre2)"; GETTEXT="$(brew --prefix gettext)"; PKGCONF="$(brew --prefix pkgconf)"
CPU="$(sysctl -n machdep.cpu.brand_string)"; EXPECTED="$(printf '%s\n' "$CPU" | sed -nE 's/^Apple M([1-9][0-9]*).*/apple-m\1/p')"; [ -n "$EXPECTED" ] || fail "unrecognized Apple CPU: $CPU"
"$CC" --print-supported-cpus -target arm64-apple-macos 2>&1 | grep -E "^[[:space:]]*$EXPECTED([[:space:]]|$)" >/dev/null || fail "Homebrew clang does not support $EXPECTED"
RESOLVED="$("$CC" -mcpu=native -### -c -x c /dev/null 2>&1 | sed -n 's/.*"-target-cpu" "\([^"]*\)".*/\1/p' | tail -1)"; [ "$RESOLVED" = "$EXPECTED" ] || fail "clang resolves native as $RESOLVED, expected $EXPECTED"
OLDPIN="$(pin_state)" || fail 'could not query Homebrew pin state'; TMP="$(mktemp -d "${TMPDIR:-/tmp}/git-native.XXXXXX")"; STAGE=''; PENDING=''; BACK=''; BACKUP_READY=0; DONE=0
cleanup(){ local s=$? restore; trap - EXIT; trap '' INT TERM; set +e; if [ "$DONE" -eq 0 ] && [ "$BACKUP_READY" -eq 1 ] && [ -f "$BACK" ]; then restore="$(dirname "$TARGET")/.git.native-restore.$$"; cp -p "$BACK" "$restore" && mv -f "$restore" "$TARGET" && rm -f "$BACK" || { warn "rollback failed; backup retained at $BACK"; s=1; }; fi; rm -f "$STAGE" "$PENDING"; if [ "$DONE" -eq 0 ]; then if [ "$OLDPIN" = pinned ]; then brew pin git >/dev/null 2>&1 || true; else brew unpin git >/dev/null 2>&1 || true; fi; [ "$(pin_state)" = "$OLDPIN" ] || s=1; fi; rm -rf "$TMP"; exit "$s"; }; trap cleanup EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
ARC="$TMP/src.tar.xz"; info 'Downloading exact Git source'; curl -fL "$URL" -o "$ARC"; [ "$(sum "$ARC")" = "$SHA" ] || fail 'source checksum mismatch'
mkdir "$TMP/src"; tar -xJf "$ARC" -C "$TMP/src" --strip-components=1
# Mandatory Homebrew replacement: compiled runtime paths must use stable opt, never Cellar.
grep -Eq -- '-DFALLBACK_RUNTIME_PREFIX="[^"]+' "$TMP/src/Makefile" || fail 'Makefile fallback definition changed'
perl -pi -e 's!(-DFALLBACK_RUNTIME_PREFIX=")[^"]+!${1}/opt/homebrew/opt/git!' "$TMP/src/Makefile"
grep -Fq -- '-DFALLBACK_RUNTIME_PREFIX="/opt/homebrew/opt/git' "$TMP/src/Makefile" || fail 'fallback replacement failed'
ARGS=("prefix=$KEG" "sysconfdir=$BREW/etc" "CC=$CC" "AR=$LLVM/bin/llvm-ar" "RANLIB=$LLVM/bin/llvm-ranlib" 'LDFLAGS=-flto' NO_TCLTK=1 NO_RUST=1 NO_OPENSSL=1 APPLE_COMMON_CRYPTO=1 USE_LIBPCRE2=1 USE_HOMEBREW_LIBICONV= NO_FINK=1 NO_DARWIN_PORTS=1 "LIBPCREDIR=$PCRE" "LIBINTL=$GETTEXT/lib/libintl.dylib" "CURLDIR=$(xcrun --show-sdk-path)/usr" "PERL_PATH=/usr/bin/perl" "SHELL_PATH=/bin/sh")
BUILD_PATH="$LLVM/bin:$PKGCONF/bin:/usr/bin:/bin:/usr/sbin:/sbin"
build(){ local dir="$1" extra="$2"; mkdir "$dir"; cp -R "$TMP/src/." "$dir/"; env -i HOME="$HOME" PATH="$BUILD_PATH" SDKROOT="$(xcrun --show-sdk-path)" make -C "$dir" clean >/dev/null; env -i HOME="$HOME" PATH="$BUILD_PATH" SDKROOT="$(xcrun --show-sdk-path)" PKG_CONFIG="$PKGCONF/bin/pkg-config" make -C "$dir" -j"$(sysctl -n hw.ncpu)" git "${ARGS[@]}" "CFLAGS=-O3 -mcpu=native -flto $extra"; }
if [ "$PGO" -eq 1 ]; then
  [ -x "$PD" ] || fail 'matching Homebrew llvm-profdata missing'; "$PD" --version | grep -Eq 'LLVM version 22\.' || fail 'llvm-profdata is not LLVM 22'
  RAW="$TMP/profiles"; mkdir "$RAW"; build "$TMP/generate" "-fprofile-generate=$RAW"; export LLVM_PROFILE_FILE="$RAW/git-%m-%p.profraw"
  GIT_BENCH_REPETITIONS=3 "$(dirname "$0")/../benchmarks/benchmark_git_native.sh" "$TMP/generate/git" pgo-training >/dev/null; unset LLVM_PROFILE_FILE
  find "$RAW" -name '*.profraw' -size +0 -print -quit | grep -q . || fail 'PGO training produced no raw profile'; "$PD" merge -o "$TMP/merged.profdata" "$RAW"/*.profraw; [ -s "$TMP/merged.profdata" ] || fail 'merged PGO profile is empty'; build "$TMP/use" "-fprofile-use=$TMP/merged.profdata"; CAND="$TMP/use/git"
else build "$TMP/build" ''; CAND="$TMP/build/git"; fi
verify(){ local g="$1" out r="$TMP/smoke-${RANDOM}"
  [ -x "$g" ] && [ "$(lipo -archs "$g")" = arm64 ] || fail 'candidate is not thin arm64'; codesign --verify --strict "$g" || fail 'invalid signature'
  [ "$($g --version)" = 'git version 2.55.0' ] || fail 'version mismatch'; out="$($g version --build-options)"; printf '%s' "$out" | grep -Fq 'sizeof-long: 8' || fail 'bad build options'
  otool -L "$g" | grep -F "$PCRE/lib/libpcre2-8" >/dev/null || fail 'PCRE2 linkage missing'; ! install_names "$g" | grep -F "$KEG" >/dev/null || fail 'Cellar linkage found'; ! rpaths "$g" | grep -F "$KEG" >/dev/null || fail 'Cellar rpath found'
  [ "$($g --exec-path)" = "$OPT/libexec/git-core" ] && [ "$($g --html-path)" = "$OPT/share/doc/git-doc" ] && [ "$($g --man-path)" = "$OPT/share/man" ] || fail 'installed runtime paths mismatch'
  HOME="$r/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "$g" init -q --initial-branch=main "$r"; export HOME="$r/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null; mkdir -p "$HOME"; "$g" -C "$r" config user.name Test; "$g" -C "$r" config user.email x@y.invalid; echo needle >"$r/a"; "$g" -C "$r" add a; "$g" -C "$r" commit -qm one; "$g" -C "$r" branch side; echo two >>"$r/a"; "$g" -C "$r" commit -qam two; "$g" -C "$r" merge -q side; "$g" -C "$r" grep needle >/dev/null; "$g" -C "$r" grep -P 'need\w+' >/dev/null; "$g" -C "$r" fsck --no-progress; "$g" -C "$r" gc --quiet; "$g" -C "$r" bundle create "$r/bundle" --all; "$g" -c protocol.file.allow=always clone -q "$r" "$r-clone"; rm -rf "$r" "$r-clone"
}
info 'Verifying candidate'; verify "$CAND"; [ "$(build_options "$CAND")" = "$BASE_OPTIONS" ] || fail 'candidate build options differ from bottle'; [ "$(install_names "$CAND")" = "$BASE_LINKS" ] || fail 'candidate install names differ from bottle'; [ "$(rpaths "$CAND")" = "$BASE_RPATHS" ] || fail 'candidate LC_RPATH list differs from bottle'; info 'Benchmarking candidate against the currently installed baseline'; GIT_BENCH_REPETITIONS="${GIT_BENCH_REPETITIONS:-5}" "$(dirname "$0")/../benchmarks/benchmark_git_native.sh" "$CAND" "$TARGET"; MODE="$(stat -f %Lp "$TARGET")"; STAGE="$(dirname "$TARGET")/.git.native-stage.$$"; PENDING="$(dirname "$TARGET")/.git.native-backup-pending.$$"; BACK="$(dirname "$TARGET")/.git.native-backup.$$"; cp "$CAND" "$STAGE"; chmod "$MODE" "$STAGE"; verify "$STAGE"; cp -p "$TARGET" "$PENDING"; mv -f "$PENDING" "$BACK"; PENDING=''; BACKUP_READY=1; mv -f "$STAGE" "$TARGET"; STAGE=''; verify "$TARGET"; [ "$(sum "$TARGET")" = "$(sum "$CAND")" ] || fail 'installed candidate mismatch'; brew pin git; [ "$(pin_state)" = pinned ] || fail 'pin failed'; trap '' INT TERM; rm -f "$BACK" || fail 'could not retire backup'; BACK=''; BACKUP_READY=0; DONE=1; trap - INT TERM; info "Installed and pinned native Git ($CPU)"
