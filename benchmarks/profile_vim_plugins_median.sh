#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VIMRC="${VIMRC_PATH:-$REPO_ROOT/.vimrc}"
VIM_BIN="${VIM_BIN:-vim}"
RUNS="${RUNS:-7}"

if ! command -v "$VIM_BIN" >/dev/null 2>&1; then
  if command -v nvim >/dev/null 2>&1; then
    VIM_BIN="nvim"
  else
    echo "Error: neither 'vim' nor 'nvim' found in PATH." >&2
    exit 1
  fi
fi

if [ ! -f "$VIMRC" ]; then
  echo "Error: vimrc not found at $VIMRC" >&2
  exit 1
fi

if ! [[ "$RUNS" =~ ^[0-9]+$ ]] || [ "$RUNS" -lt 1 ]; then
  echo "Error: RUNS must be a positive integer." >&2
  exit 1
fi

plugin_values=()
total_values=()

echo "Running $RUNS startup profile iterations..."
for i in $(seq 1 "$RUNS"); do
  log_file="$(mktemp -t vim-startuptime.XXXXXX.log)"
  "$VIM_BIN" -Nu "$VIMRC" -i NONE -n --startuptime "$log_file" +qall >/dev/null 2>&1

  plugin_ms="$(awk '
    /sourcing / {
      t = $2
      gsub(":", "", t)
      if (t !~ /^[0-9.]+$/) next

      path = ""
      for (j = 4; j <= NF; j++) {
        path = path (j == 4 ? "" : " ") $j
      }

      if (index(path, "/.vim/pack/bundles/start/") > 0) sum += t
    }
    END { printf "%.3f", sum + 0 }
  ' "$log_file")"

  total_ms="$(awk '
    /^[[:space:]]*[0-9]+\.[0-9]+/ {
      t = $1
      gsub(":", "", t)
      if (t ~ /^[0-9.]+$/) last = t
    }
    END { printf "%.3f", last + 0 }
  ' "$log_file")"

  plugin_values+=("$plugin_ms")
  total_values+=("$total_ms")

  printf "Run %d: plugin_start_total=%sms total_startup=%sms\n" "$i" "$plugin_ms" "$total_ms"
  rm -f "$log_file"
done

median() {
  printf '%s\n' "$@" | sort -n | awk '
    { vals[NR] = $1 }
    END {
      if (NR == 0) {
        print "0.000"
      } else if (NR % 2 == 1) {
        printf "%.3f", vals[(NR + 1) / 2]
      } else {
        printf "%.3f", (vals[NR / 2] + vals[(NR / 2) + 1]) / 2
      }
    }
  '
}

echo
echo "Median results ($RUNS runs):"
echo "- plugin_start_total_ms=$(median "${plugin_values[@]}")"
echo "- total_startup_ms=$(median "${total_values[@]}")"
