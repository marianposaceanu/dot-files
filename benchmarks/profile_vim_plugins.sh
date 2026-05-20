#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VIMRC="${VIMRC_PATH:-$REPO_ROOT/.vimrc}"
VIM_BIN="${VIM_BIN:-vim}"

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

LOG_FILE="$(mktemp -t vim-startuptime.XXXXXX.log)"

"$VIM_BIN" -Nu "$VIMRC" -i NONE -n -es --startuptime "$LOG_FILE" -c qall >/dev/null 2>&1

echo "Vim startup profile log: $LOG_FILE"
echo
echo "Top sourced files by self+sourced time (ms):"
awk '
  /sourcing / {
    t = $2
    gsub(":", "", t)
    if (t ~ /^[0-9.]+$/) {
      path = ""
      for (i = 4; i <= NF; i++) {
        path = path (i == 4 ? "" : " ") $i
      }
      printf "%10.3f\t%s\n", t, path
    }
  }
' "$LOG_FILE" | sort -nr | head -20

echo
echo "Plugin totals under .vim/pack/bundles/start (ms):"
awk '
  /sourcing / {
    t = $2
    gsub(":", "", t)
    if (t !~ /^[0-9.]+$/) next

    path = ""
    for (i = 4; i <= NF; i++) {
      path = path (i == 4 ? "" : " ") $i
    }

    if (index(path, "/.vim/pack/bundles/start/") > 0) {
      plugin_path = path
      sub(/^.*\/\.vim\/pack\/bundles\/start\//, "", plugin_path)
      split(plugin_path, parts, "/")
      plugin = parts[1]
      sum[plugin] += t
      count[plugin] += 1
    }
  }

  END {
    for (p in sum) {
      printf "%10.3f\t%4d files\t%s\n", sum[p], count[p], p
    }
  }
' "$LOG_FILE" | sort -nr

echo
echo "Tip: run multiple times and compare medians for stability."
