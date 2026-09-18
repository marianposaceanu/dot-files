#!/usr/bin/env bash
# bootstrap/native/brew_native.sh
#
# Build vim, git, ripgrep and universal-ctags through Homebrew itself, but
# tuned for the local Apple Silicon CPU, via a local tap (marian/local).
#
# Why a tap instead of patching binaries into the keg (the older
# compile_*_native.sh scripts)? Homebrew's superenv compiler shim strips any
# -O/-mcpu flag a formula or the environment passes and injects nothing for
# Apple CPUs, so `brew reinstall --build-from-source` yields a generic arm64
# build. The `--env=std` escape hatch is disabled in current Homebrew. A
# formula can still opt into stdenv with `env :std`, and stdenv uses the real
# clang with CFLAGS honoured. So for each tool this script:
#
#   1. copies the current homebrew-core formula,
#   2. strips the bottle block, adds `env :std` and the native flags,
#   3. saves the result to bootstrap/native/formulas/<name>.rb (versioned),
#   4. syncs it into the marian/local tap,
#   5. uninstall the core keg, `brew install --build-from-source marian/local/<name>`, `brew pin`.
#
# Because brew itself owns the build, `brew upgrade` no longer silently
# replaces the tuned binary with a bottle: the tap formula is what gets built.
#
# Usage:
#   ./bootstrap/native/brew_native.sh                 # all four tools
#   ./bootstrap/native/brew_native.sh vim ripgrep     # a subset
#   ./bootstrap/native/brew_native.sh --formulas-only # regenerate .rb files, no build
#
# Env overrides:
#   NATIVE_CPU=apple-m4   skip -mcpu=native detection
#   TAP=marian/local      tap name

set -euo pipefail

TAP="${TAP:-marian/local}"
ALL_TOOLS=(vim git ripgrep universal-ctags)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FORMULA_DIR="$REPO_DIR/bootstrap/native/formulas"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m ✔\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

FORMULAS_ONLY=0
TOOLS=()
for arg in "$@"; do
  case "$arg" in
    --formulas-only) FORMULAS_ONLY=1 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) TOOLS+=("$arg") ;;
  esac
done
[ ${#TOOLS[@]} -eq 0 ] && TOOLS=("${ALL_TOOLS[@]}")

[ "$(uname -m)" = arm64 ] || fail "This script targets Apple Silicon only."
command -v brew >/dev/null || fail "Homebrew not found."

# Resolve -mcpu=native to a concrete Apple CPU name so the flag is explicit in
# the saved formula and in `vim --version`.
if [ -z "${NATIVE_CPU:-}" ]; then
  NATIVE_CPU="$(clang -mcpu=native -### -x c /dev/null 2>&1 \
    | grep -oE '"-target-cpu" "[^"]+"' | head -1 | cut -d'"' -f4 || true)"
fi
[ -n "$NATIVE_CPU" ] || fail "Could not resolve -mcpu=native; set NATIVE_CPU=apple-mN."
NATIVE_CFLAGS="-O3 -mcpu=${NATIVE_CPU}"
info "Native CPU: ${NATIVE_CPU}   CFLAGS: ${NATIVE_CFLAGS}"

# ── Tap ─────────────────────────────────────────────────────────────────────
if ! brew tap | grep -qx "$TAP"; then
  info "Creating local tap $TAP"
  brew tap-new --no-git "$TAP" >/dev/null
fi
TAP_FORMULA_DIR="$(brew --repo "$TAP")/Formula"
mkdir -p "$TAP_FORMULA_DIR" "$FORMULA_DIR"

# ── Formula patching ────────────────────────────────────────────────────────
# patch_formula <core.rb> <out.rb> <name>
patch_formula() {
  python3 - "$1" "$2" "$3" "$NATIVE_CPU" "$NATIVE_CFLAGS" <<'PY'
import re, sys
src, out, name, cpu, cflags = sys.argv[1:6]
s = open(src).read()

# Never try to fetch a bottle; we always build.
s = re.sub(r'\n  bottle do.*?\n  end\n', '\n', s, count=1, flags=re.S)

header = (
    "  # ── native build (bootstrap/native/brew_native.sh) ──\n"
    "  # stdenv so the real clang sees our CFLAGS; superenv would strip them.\n"
    "  env :std\n\n"
)
inject = f'    ENV.append_to_cflags "{cflags}"\n'

if name == "ripgrep":
    # Rust: cargo ignores CFLAGS; drive codegen via RUSTFLAGS and use the
    # upstream release-lto profile (fat LTO, 1 codegen unit, panic=abort).
    inject = (
        f'    ENV["RUSTFLAGS"] = "-C target-cpu={cpu}"\n'
        f'    ENV.append_to_cflags "{cflags}" # for the bundled pcre2 C build\n'
    )
    s = s.replace(
        'system "cargo", "install", *std_cargo_args(features: "pcre2")',
        'system "cargo", "install", "--profile", "release-lto", *std_cargo_args(features: "pcre2")',
        1,
    )

if name == "vim":
    s = s.replace(
        '"--with-compiledby=Homebrew",',
        f'"--with-compiledby=native-{cpu}",\n'
        f'                          "--with-modified-by=[ {cpu} :: {cflags} ]",',
        1,
    )

marker = "  def install\n"
assert marker in s, f"{name}: no `def install` found"
s = s.replace(marker, header + marker + inject, 1)
open(out, "w").write(s)
PY
}

# ── Main loop ───────────────────────────────────────────────────────────────
for tool in "${TOOLS[@]}"; do
  case " ${ALL_TOOLS[*]} " in *" $tool "*) ;; *) fail "Unknown tool: $tool (known: ${ALL_TOOLS[*]})";; esac

  info "[$tool] generating formula from homebrew-core"
  core_rb="$(brew formula "homebrew/core/$tool")"
  patch_formula "$core_rb" "$FORMULA_DIR/$tool.rb" "$tool"
  cp "$FORMULA_DIR/$tool.rb" "$TAP_FORMULA_DIR/$tool.rb"
  ok "[$tool] saved $FORMULA_DIR/$tool.rb and synced to $TAP"

  [ "$FORMULAS_ONLY" = 1 ] && continue

  info "[$tool] building via brew (this compiles from source)"
  brew unpin "$tool" >/dev/null 2>&1 || true
  # NOTE: `brew reinstall $TAP/$tool` on a keg that came from homebrew-core
  # silently reuses the core formula (the receipt's source), so the tap
  # formula is never used. Uninstall first so `install` resolves to the tap.
  if brew list --versions "$tool" >/dev/null 2>&1; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew uninstall --ignore-dependencies "$tool"
  fi
  HOMEBREW_NO_AUTO_UPDATE=1 brew install --build-from-source "$TAP/$tool"
  brew pin "$tool" >/dev/null
  ok "[$tool] installed from $TAP and pinned"
done

[ "$FORMULAS_ONLY" = 1 ] && exit 0

# ── Verify ──────────────────────────────────────────────────────────────────
info "Verification"
for tool in "${TOOLS[@]}"; do
  case "$tool" in
    vim)  vim --version | grep -E "Modified by|Compiled by" | sed 's/^/  vim: /' ;;
    git)  printf '  git: %s\n' "$(git --version)" ;;
    ripgrep) printf '  rg: %s\n' "$(rg --version | head -1)" ;;
    universal-ctags) printf '  ctags: %s\n' "$(ctags --version | head -1)" ;;
  esac
done
brew list --pinned | sed 's/^/  pinned: /'
