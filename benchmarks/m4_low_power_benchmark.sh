#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./benchmarks/m4_low_power_benchmark.sh normal|low [iterations]

Run the SHA-256 and Speedometer 3.1 workloads used for the M4 MacBook Air
Low Power Mode comparison. The script verifies the selected battery mode but
does not change it. Select Never (normal) or Only on Battery (low) in:

  System Settings > Battery > Low Power Mode
EOF
}

case "${1:-}" in
  normal) expected_mode=0 ;;
  low) expected_mode=1 ;;
  *) usage >&2; exit 2 ;;
esac

iterations="${2:-5}"
chrome="${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
root="$(cd "$(dirname "$0")/.." && pwd)"
timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
result="$root/benchmarks/results/m4-low-power-$1-$timestamp.txt"

for command in openssl node pmset awk system_profiler; do
  command -v "$command" >/dev/null || {
    printf 'Error: required command not found: %s\n' "$command" >&2
    exit 1
  }
done

[[ -x "$chrome" ]] || {
  printf 'Error: Chrome executable not found: %s\n' "$chrome" >&2
  exit 1
}

mode="$({ pmset -g custom || true; } |
  awk '/Battery Power:/{battery=1;next}/AC Power:/{battery=0} battery&&/lowpowermode/{print $2}')"
[[ "$mode" == "$expected_mode" ]] || {
  printf 'Error: expected battery lowpowermode=%s, found %s.\n' "$expected_mode" "${mode:-unknown}" >&2
  printf 'Change it in System Settings; this script deliberately does not use sudo.\n' >&2
  exit 1
}

mkdir -p "$(dirname "$result")"

{
  printf 'mode=%s\n' "$1"
  printf 'battery_lowpowermode=%s\n' "$mode"
  printf 'started=%s\n' "$(date -u '+%FT%TZ')"
  printf 'macos=%s build=%s\n' "$(sw_vers -productVersion)" "$(sw_vers -buildVersion)"
  system_profiler SPHardwareDataType |
    awk -F': ' '/Model Name|Model Identifier|Chip|Total Number of Cores|Memory/{gsub(/^[[:space:]]+/, "", $1); print $1 "=" $2}'
  "$chrome" --version
  openssl version
  node --version
  pmset -g batt | tail -1
  pmset -g therm

  for run in 1 2 3; do
    openssl speed -seconds 5 -evp sha256 2>&1 |
      awk -v run="$run" '/^sha256/{print "sha256_run=" run " sha256_8192_kBps=" $NF}'
  done

  node "$root/benchmarks/speedometer_runner.mjs" "$iterations"
  printf 'finished=%s\n' "$(date -u '+%FT%TZ')"
} | tee "$result"

printf '\nSaved %s\n' "$result"
