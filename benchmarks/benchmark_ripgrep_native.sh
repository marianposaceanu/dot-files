#!/usr/bin/env bash

set -euo pipefail

RG_BINARY="${1:-$(command -v rg || true)}"
LABEL="${2:-$(basename "$RG_BINARY")}"
COMPARE_BINARY="${3:-}"
COMPARE_LABEL="${4:-$(basename "${COMPARE_BINARY:-comparison}")}"
CORPUS="${RG_BENCH_CORPUS:-${TMPDIR:-/tmp}/ripgrep-native-benchmark-corpus-v1}"
REPETITIONS="${RG_BENCH_REPETITIONS:-9}"

if [ -z "$RG_BINARY" ] || [ ! -x "$RG_BINARY" ]; then
  echo "Usage: $0 /path/to/rg [label] [/path/to/comparison-rg comparison-label]" >&2
  exit 1
fi
if [ -n "$COMPARE_BINARY" ] && [ ! -x "$COMPARE_BINARY" ]; then
  echo "Comparison binary is not executable: $COMPARE_BINARY" >&2
  exit 1
fi
if ! [[ "$REPETITIONS" =~ ^[1-9][0-9]*$ ]]; then
  echo "RG_BENCH_REPETITIONS must be a positive integer." >&2
  exit 1
fi

if [ ! -f "$CORPUS/.complete" ]; then
  if [ -e "$CORPUS" ]; then
    echo "Refusing to replace an existing incomplete corpus: $CORPUS" >&2
    exit 1
  fi
  echo "Preparing deterministic benchmark corpus at $CORPUS ..." >&2
  mkdir -p "$CORPUS/large" "$CORPUS/small"
  python3 - "$CORPUS" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
lines = []
for index in range(8192):
    suffix = ""
    if index % 257 == 0:
        suffix += " NEEDLE_native_rg_7d3f91a2"
    if index % 509 == 0:
        suffix += " error_code=ERR2048 path=/api/v3/search-index"
    if index % 769 == 0:
        suffix += " request_id=0123456789abcdef;"
    lines.append(
        f"{index:05d} level=info résumé naïve payload="
        "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        " repeated-search-data-for-native-ripgrep-benchmark"
        f"{suffix}\n"
    )
block = "".join(lines).encode()
for index in range(128):
    (root / "large" / f"input-{index:04d}.log").write_bytes(block)
small = b"ordinary searchable content without the benchmark sentinel\n" * 8
for index in range(5000):
    directory = root / "small" / f"group-{index // 100:03d}"
    directory.mkdir(exist_ok=True)
    (directory / f"item-{index:05d}.txt").write_bytes(small)
(root / ".complete").write_text("ripgrep-native-benchmark-corpus-v1\n")
PY
fi

echo "Binary: $RG_BINARY" >&2
echo "Version: $($RG_BINARY --version | head -1)" >&2
[ -z "$COMPARE_BINARY" ] \
  || echo "Comparison: $COMPARE_BINARY ($($COMPARE_BINARY --version | head -1))" >&2
echo "Corpus: $CORPUS ($(du -sh "$CORPUS" | awk '{print $1}'))" >&2
echo "Repetitions: $REPETITIONS after 2 warmups" >&2

python3 - "$RG_BINARY" "$LABEL" "$CORPUS" "$REPETITIONS" \
  "$COMPARE_BINARY" "$COMPARE_LABEL" <<'PY'
import statistics
import subprocess
import sys
import time

binary, label, corpus, repetitions = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
comparison, comparison_label = sys.argv[5], sys.argv[6]
large = f"{corpus}/large"
small = f"{corpus}/small"
cases = [
    ("literal, one thread", ["--threads", "1", "--count", "NEEDLE_native_rg_7d3f91a2", large]),
    ("regex, one thread", ["--threads", "1", "--count", r"error_code=[A-Z]{3}[0-9]{4} path=/api/v[0-9]+/[[:alnum:]_-]+", large]),
    ("Unicode regex, one thread", ["--threads", "1", "--count", r"(?i)résumé\s+naïve", large]),
    ("PCRE2 lookaround, one thread", ["--threads", "1", "--pcre2", "--count", r"(?<=request_id=)[a-f0-9]{16}(?=;)", large]),
    ("literal, two threads", ["--threads", "2", "--count", "NEEDLE_native_rg_7d3f91a2", large]),
    ("literal, four threads", ["--threads", "4", "--count", "NEEDLE_native_rg_7d3f91a2", large]),
    ("literal, eight threads", ["--threads", "8", "--count", "NEEDLE_native_rg_7d3f91a2", large]),
    ("literal, default threads", ["--count", "NEEDLE_native_rg_7d3f91a2", large]),
    ("5,000-file traversal", ["--files", small]),
]

def run(executable, arguments):
    started = time.perf_counter_ns()
    result = subprocess.run(
        [executable, "--no-config", "--no-messages", *arguments],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        check=False,
    )
    elapsed_ms = (time.perf_counter_ns() - started) / 1_000_000
    if result.returncode not in (0, 1):
        sys.stderr.write(result.stderr.decode(errors="replace"))
        raise SystemExit(f"benchmark command failed with exit status {result.returncode}")
    return elapsed_ms

print(f"# ripgrep benchmark: {label}")
print()
if not comparison:
    print("| Workload | Median | Minimum | Maximum |")
    print("| --- | ---: | ---: | ---: |")
    for name, arguments in cases:
        for _ in range(2):
            run(binary, arguments)
        samples = [run(binary, arguments) for _ in range(repetitions)]
        print(
            f"| {name} | {statistics.median(samples):.2f} ms | "
            f"{min(samples):.2f} ms | {max(samples):.2f} ms |"
        )
else:
    print(f"| Workload | {label} | {comparison_label} | {label} change |")
    print("| --- | ---: | ---: | ---: |")
    for name, arguments in cases:
        for _ in range(2):
            run(binary, arguments)
            run(comparison, arguments)
        samples = []
        comparison_samples = []
        for repetition in range(repetitions):
            order = (binary, comparison) if repetition % 2 == 0 else (comparison, binary)
            measured = {executable: run(executable, arguments) for executable in order}
            samples.append(measured[binary])
            comparison_samples.append(measured[comparison])
        median = statistics.median(samples)
        comparison_median = statistics.median(comparison_samples)
        change = ((median / comparison_median) - 1) * 100
        print(
            f"| {name} | {median:.2f} ms | {comparison_median:.2f} ms | "
            f"{change:+.1f}% |"
        )
PY
