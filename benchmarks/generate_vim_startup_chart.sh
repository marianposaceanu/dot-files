#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BENCH_DIR="$REPO_ROOT/benchmarks"

labels=(
  "with_polyglot"
  "without_polyglot"
  "after_lazyload_opt_plugins"
  "lightline_only"
  "after_ack_removal_tabular_opt"
  "after_fugitive_opt"
)

files=(
  "vim_startup_profile_with_polyglot.txt"
  "vim_startup_profile_without_polyglot.txt"
  "vim_startup_profile_after_lazyload_opt_plugins.txt"
  "vim_startup_profile_lightline_only.txt"
  "vim_startup_profile_after_ack_removal_tabular_opt.txt"
  "vim_startup_profile_after_fugitive_opt.txt"
)

extract_total() {
  local file="$1"
  awk '
    /Plugin totals under \.vim\/pack\/bundles\/start/ {flag=1; next}
    /Tip:/ {flag=0}
    flag && NF > 0 {sum += $1}
    END {printf "%.3f", sum + 0}
  ' "$file"
}

totals=()
best_index=0
best_value=""

for i in "${!labels[@]}"; do
  file="$BENCH_DIR/${files[$i]}"

  if [ ! -f "$file" ]; then
    echo "Error: missing benchmark file: $file" >&2
    exit 1
  fi

  total="$(extract_total "$file")"
  totals+=("$total")

  if [ -z "$best_value" ] || awk "BEGIN { exit !($total < $best_value) }"; then
    best_index="$i"
    best_value="$total"
  fi
done

ratio() {
  awk -v a="$1" -v b="$2" 'BEGIN {printf "%.2f", a / b}'
}

bar() {
  local r="$1"
  local width=20
  local filled
  filled="$(awk -v rv="$r" -v w="$width" 'BEGIN { n = int(rv * 2 + 0.5); if (n < 1) n = 1; if (n > w) n = w; print n }')"
  local empty=$((width - filled))
  printf "%${filled}s" "" | tr ' ' '#'
  printf "%${empty}s" "" | tr ' ' '.'
}

line() {
  printf "+---------------------------------------------------------------------------------------+\n"
}

row() {
  printf "| %-85s |\n" "$1"
}

center_row() {
  local text="$1"
  local width=85
  local len=${#text}
  local left=$(((width - len) / 2))
  local right=$((width - len - left))
  printf "| %*s%s%*s |\n" "$left" "" "$text" "$right" ""
}

line
center_row "MY DOT FILES"
row ""
center_row ".-=--."
center_row ".' .--. '."
center_row ":  : .-.'. :    _ _"
center_row ":  : : .': :   (o)o)"
center_row ":  '. '-' .'   ////"
center_row "_'.__'--=' '-.//'"
center_row ".-'               /"
center_row "'---..____...---''"
row ""
row "VIM STARTUP IMPROVEMENT MAP (plugin_start_total ms; lower is better)"
line

for i in "${!labels[@]}"; do
  label="${labels[$i]}"
  total="${totals[$i]}"
  r="$(ratio "$total" "$best_value")"
  b="$(bar "$r")"
  if [ "$i" -eq "$best_index" ]; then
    row "$(printf "%-34s %7.3f ms   (%4.2fx best)    [%s]" "$label" "$total" "$r" "$b")"
  else
    row "$(printf "%-34s %7.3f ms   (%4.2fx vs best) [%s]" "$label" "$total" "$r" "$b")"
  fi
done

row ""
row "$(printf "Overall improvement: %.3f ms -> %.3f ms  (~%sx lower plugin startup load)" "${totals[0]}" "${totals[5]}" "$(ratio "${totals[0]}" "${totals[5]}")")"
line
