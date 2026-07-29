#!/usr/bin/env bash
# Reproducible, isolated Git CPU benchmark.  No configuration outside the
# temporary repository is read or written.
set -euo pipefail

usage() { echo "Usage: $0 GIT [GIT2|pgo-training] [--warmups N] [--repetitions N]" >&2; exit 2; }
GIT1="${1:-}"; [ -n "$GIT1" ] || usage; shift
GIT2=""; TRAIN=0
if [ "${1:-}" = pgo-training ] || [ "${1:-}" = --training ]; then TRAIN=1; shift
elif [ -n "${1:-}" ] && [ "${1#--}" = "$1" ]; then GIT2="$1"; shift; fi
WARMUPS="${GIT_BENCH_WARMUPS:-2}"; REPS="${GIT_BENCH_REPETITIONS:-7}"
while [ $# -gt 0 ]; do case "$1" in
  --warmups) [ $# -ge 2 ] || usage; WARMUPS="$2"; shift 2;;
  --repetitions) [ $# -ge 2 ] || usage; REPS="$2"; shift 2;;
  *) usage;; esac; done
case "$WARMUPS:$REPS" in *[!0-9:]*) usage;; esac
[ "$REPS" -gt 0 ] || usage
for g in "$GIT1" ${GIT2:+"$GIT2"}; do [ -x "$g" ] || { echo "Not executable: $g" >&2; exit 1; }; done

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/git-native-bench.XXXXXX")"
cleanup() { rm -rf "$ROOT"; }; trap cleanup EXIT INT TERM
export HOME="$ROOT/home" XDG_CONFIG_HOME="$ROOT/xdg" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
mkdir -p "$HOME" "$ROOT/repo"
run() { "$GIT1" -c core.hooksPath=/dev/null -C "$ROOT/repo" "$@"; }
run init -q --initial-branch=main
run config user.name Benchmark
run config user.email benchmark.invalid@example.invalid
for c in $(seq 1 30); do
  mkdir -p "$ROOT/repo/src" "$ROOT/repo/docs"
  for n in $(seq 1 80); do
    printf 'commit=%03d file=%03d deterministic needle_%d\nrequest_id=%08dabcdef\n' "$c" "$n" "$((n%11))" "$((c*1000+n))" >"$ROOT/repo/src/file-$n.txt"
  done
  printf '# Revision %03d\nThe deterministic benchmark corpus.\n' "$c" >"$ROOT/repo/docs/revision.md"
  run add --all; run commit -q -m "revision $c"
done
run branch side HEAD~10; run commit-graph write --reachable
printf 'dirty deterministic line\n' >>"$ROOT/repo/src/file-1.txt"

workloads() { local g="$1" repo="$2"
  "$g" -C "$repo" status --short >/dev/null
  "$g" -C "$repo" diff --stat HEAD >/dev/null
  "$g" -C "$repo" grep -n deterministic HEAD >/dev/null
  "$g" -C "$repo" grep -P 'request_id=\d{8}[a-f]+' HEAD >/dev/null
  "$g" -C "$repo" log --all --oneline --decorate=no >/dev/null
  "$g" -C "$repo" rev-list --all --objects >/dev/null
  "$g" -C "$repo" fsck --no-progress >/dev/null
  "$g" -C "$repo" commit-graph verify --shallow >/dev/null
}
capture() { local g="$1" repo="$2" status=0
  for spec in 'status --short' 'diff --stat HEAD' 'grep -n deterministic HEAD' \
    "grep -P request_id=\\d{8}[a-f]+ HEAD" 'log --all --oneline --decorate=no' \
    'rev-list --all --objects' 'fsck --no-progress' 'commit-graph verify --shallow'; do
    printf -- '--- %s\n' "$spec"
    # This corpus contains no whitespace in arguments; splitting is intentional.
    # shellcheck disable=SC2086
    "$g" -C "$repo" $spec || status=$?
    printf -- '--- exit %s\n' "$status"
    [ "$status" -eq 0 ] || return "$status"
  done
}
if [ "$TRAIN" -eq 1 ]; then
  for _ in $(seq 1 "$REPS"); do workloads "$GIT1" "$ROOT/repo"; done
  # Mutating pack/bundle/clone exercises happen only in disposable copies.
  cp -R "$ROOT/repo" "$ROOT/train-copy"
  "$GIT1" -C "$ROOT/train-copy" gc --quiet
  "$GIT1" -C "$ROOT/train-copy" bundle create "$ROOT/train.bundle" --all
  "$GIT1" -c protocol.file.allow=always clone -q "$ROOT/train-copy" "$ROOT/train-clone"
  exit 0
fi

TIME="/usr/bin/time"; [ -x "$TIME" ] || { echo '/usr/bin/time is required' >&2; exit 1; }
if [ -n "$GIT2" ]; then
  S1="$ROOT/semantics.one"; S2="$ROOT/semantics.two"
  if capture "$GIT1" "$ROOT/repo" >"$S1" 2>&1; then E1=0; else E1=$?; fi
  if capture "$GIT2" "$ROOT/repo" >"$S2" 2>&1; then E2=0; else E2=$?; fi
  [ "$E1" -eq "$E2" ] && cmp -s "$S1" "$S2" || { echo 'Git workload stdout/exit semantics differ' >&2; exit 1; }
fi
measure() { local g="$1" out="$2" t
  t="$(mktemp "$ROOT/time.XXXXXX")"; "$TIME" -p bash -c 'workloads "$1" "$2"' _ "$g" "$ROOT/repo" 2>"$t"
  awk '/^user /{u=$2}/^sys /{s=$2}END{printf "%.6f\n",u+s}' "$t" >>"$out"; rm -f "$t"
}
# Export functions because macOS time can only execute a process, not a function.
export -f workloads
for g in "$GIT1" ${GIT2:+"$GIT2"}; do for _ in $(seq 1 "$WARMUPS"); do workloads "$g" "$ROOT/repo"; done; done
O1="$ROOT/one.times"; O2="$ROOT/two.times"; : >"$O1"; : >"$O2"
for i in $(seq 1 "$REPS"); do
  if [ -z "$GIT2" ] || [ $((i % 2)) -eq 1 ]; then measure "$GIT1" "$O1"; [ -z "$GIT2" ] || measure "$GIT2" "$O2"
  else measure "$GIT2" "$O2"; measure "$GIT1" "$O1"; fi
done
median() { sort -n "$1" | awk '{a[NR]=$1}END{if(NR%2) print a[(NR+1)/2]; else printf "%.6f\n",(a[NR/2]+a[NR/2+1])/2}'; }
printf '%s\tmedian CPU seconds: %s\n' "$GIT1" "$(median "$O1")"
[ -z "$GIT2" ] || printf '%s\tmedian CPU seconds: %s\n' "$GIT2" "$(median "$O2")"
