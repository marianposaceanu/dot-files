#!/usr/bin/env bash
# Deterministic Universal Ctags parser benchmark and PGO training workload.

set -euo pipefail

CTAGS_BINARY="${1:-$(command -v ctags || true)}"
LABEL="${2:-$(basename "${CTAGS_BINARY:-ctags}")}"
COMPARE_BINARY="${3:-}"
COMPARE_LABEL="${4:-$(basename "${COMPARE_BINARY:-comparison}")}"
REPETITIONS="${CTAGS_BENCH_REPETITIONS:-9}"
WARMUPS="${CTAGS_BENCH_WARMUPS:-2}"

die() { printf 'Error: %s\n' "$1" >&2; exit 1; }
[ -x "$CTAGS_BINARY" ] || die "Usage: $0 /path/to/ctags [label] [/path/to/comparison-ctags comparison-label]"
[ -z "$COMPARE_BINARY" ] || [ -x "$COMPARE_BINARY" ] \
  || die "Comparison binary is not executable: $COMPARE_BINARY"
[[ "$REPETITIONS" =~ ^[1-9][0-9]*$ ]] || die "CTAGS_BENCH_REPETITIONS must be a positive integer."
[[ "$WARMUPS" =~ ^[0-9]+$ ]] || die "CTAGS_BENCH_WARMUPS must be a non-negative integer."

# mktemp creates a new path, so cleanup can never remove a caller-owned tree.
CORPUS="$(mktemp -d "${TMPDIR:-/tmp}/ctags-native-benchmark.XXXXXX")"
cleanup() { rm -rf -- "$CORPUS"; }
trap cleanup EXIT
mkdir "$CORPUS/c" "$CORPUS/ruby" "$CORPUS/data" "$CORPUS/mixed"
python3 - "$CORPUS" <<'PY'
from pathlib import Path
import sys
r = Path(sys.argv[1])
for i in range(240):
    c = ''.join(f'static int native_func_{i}_{j}(int x) {{ return x + {j}; }}\n' for j in range(90))
    (r/'c'/f'unit_{i:03}.c').write_text('#include <stdint.h>\n'+c)
for i in range(180):
    rb = ''.join(f'  def parser_method_{i}_{j}(value)\n    value + {j}\n  end\n' for j in range(70))
    (r/'ruby'/f'model_{i:03}.rb').write_text(f'class NativeModel{i}\n{rb}end\n')
for i in range(160):
    (r/'data'/f'object_{i:03}.json').write_text('{"name":"object_%d","items":[%s]}\n' % (i, ','.join(str(x) for x in range(300))))
    (r/'data'/f'config_{i:03}.yaml').write_text('service_%d:\n  enabled: true\n  routes:\n%s' % (i, ''.join(f'    route_{j}: /api/{i}/{j}\n' for j in range(120))))
for i in range(120):
    (r/'mixed'/f'header_{i:03}.h').write_text(f'typedef struct Native{i} {{ int value; }} Native{i};\n')
    (r/'mixed'/f'script_{i:03}.rb').write_text(f'module Mixed{i}\n  VALUE = {i}\nend\n')
    (r/'mixed'/f'package_{i:03}.json').write_text('{"package_%d":{"version":"1.0"}}\n' % i)
    (r/'mixed'/f'document_{i:03}.yaml').write_text(f'document_{i}:\n  title: native benchmark\n')
PY

printf 'Binary: %s (%s)\n' "$CTAGS_BINARY" "$($CTAGS_BINARY --version | head -1)" >&2
[ -z "$COMPARE_BINARY" ] || printf 'Comparison: %s (%s)\n' "$COMPARE_BINARY" "$($COMPARE_BINARY --version | head -1)" >&2
printf 'Corpus: fresh deterministic temporary tree; repetitions: %s; warmups: %s\n' "$REPETITIONS" "$WARMUPS" >&2

python3 - "$CTAGS_BINARY" "$LABEL" "$CORPUS" "$REPETITIONS" "$WARMUPS" "$COMPARE_BINARY" "$COMPARE_LABEL" <<'PY'
import statistics, subprocess, sys, time
binary, label, root = sys.argv[1:4]
reps, warmups = map(int, sys.argv[4:6])
other, other_label = sys.argv[6:8]
cases = [
    ('C parser', ['--languages=C', root+'/c']),
    ('Ruby parser', ['--languages=Ruby', root+'/ruby']),
    ('JSON and YAML parsers', ['--languages=JSON,Yaml', root+'/data']),
    ('representative mixed parsers', ['--languages=C,Ruby,JSON,Yaml', root+'/mixed']),
]
def run(exe, args):
    start = time.perf_counter_ns()
    p = subprocess.run([exe, '--options=NONE', '--sort=no', '-f', '/dev/null', '-R', *args],
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if p.returncode:
        sys.stderr.write(p.stderr.decode(errors='replace'))
        raise SystemExit(f'ctags benchmark failed with status {p.returncode}')
    return (time.perf_counter_ns()-start)/1e6
def semantic(exe, args):
    p = subprocess.run([exe, '--options=NONE', '--sort=yes', '--output-format=json', '-f', '-', '-R', *args],
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return p.returncode, p.stdout, p.stderr
print(f'# Universal Ctags benchmark: {label}\n')
if not other:
    print('| Workload | Median | Minimum | Maximum |\n| --- | ---: | ---: | ---: |')
else:
    print(f'| Workload | {label} | {other_label} | {label} change |\n| --- | ---: | ---: | ---: |')
for name, args in cases:
    if other:
        left, right = semantic(binary,args), semantic(other,args)
        if left != right:
            raise SystemExit(f'non-equivalent deterministic tag output for {name}')
    for _ in range(warmups):
        run(binary,args)
        if other: run(other,args)
    a=[]; b=[]
    for i in range(reps):
        order=[binary,other] if i%2 == 0 else [other,binary]
        measured={x:run(x,args) for x in order if x}
        a.append(measured[binary])
        if other: b.append(measured[other])
    ma=statistics.median(a)
    if other:
        mb=statistics.median(b)
        print(f'| {name} | {ma:.2f} ms | {mb:.2f} ms | {(ma/mb-1)*100:+.1f}% |')
    else:
        print(f'| {name} | {ma:.2f} ms | {min(a):.2f} ms | {max(a):.2f} ms |')
PY
