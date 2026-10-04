# Benchmarks

All benchmark logic runs in Babashka/Clojure. Run the `.clj` entry points from the
repository root. Babashka includes the filesystem, process, XML, JSON, HTTP, and
WebSocket support used here; Python and Node.js are no longer required.

The previous scripts, documentation, results, and regression harness are preserved
in [archive/benchmarks-shell-20261004.tar.gz](archive/benchmarks-shell-20261004.tar.gz),
with a checksum and [extraction instructions](archive/README.md).

Historical startup captures and the shell chart generator are preserved in the
archive; no loose historical profile captures remain. The published chart values
are retained in [the article](../docs/native-apple-silicon-builds.html) and the
[M1 Pro run report](results/m1-pro-20261004/README.md).

## Entry points

| Entry point | Purpose | Requirements and output |
| --- | --- | --- |
| `profile_vim_plugins.clj` | Single startup profile, file and plugin self times | Vim or Neovim, selected `.vimrc`, initialized plugins; retained temporary log |
| `profile_vim_plugins_median.clj` | Repeated startup profiles and medians | Same; `RUNS=7`; temporary logs cleaned up |
| `vim_bench.clj` | Regex, replacement, sorting, and Vimscript workloads | Vim, `strings`; corpus and timestamped reports below this directory |
| `benchmark_ripgrep_native.clj` | Search, Unicode, PCRE2, threads, and traversal | ripgrep with PCRE2; reusable temporary corpus; Markdown on stdout |
| `benchmark_ctags_native.clj` | C, Ruby, JSON, YAML, and mixed parsing | Universal Ctags with JSON output; disposable corpus; Markdown on stdout |
| `benchmark_git_native.clj` | Git CPU workloads and PGO training | Git with PCRE2, `/usr/bin/time`, Bash for the timed Git payload; disposable repo |
| `low_power/m4_low_power_benchmark.clj` | SHA-256 throughput and Speedometer 3.1 | macOS, OpenSSL, Chrome, internet; completed timestamped text report |
| `low_power/m4_power_benchmark.clj` | Whole-system battery draw during idle, warmup, and load | macOS AppleSmartBattery telemetry and OpenSSL; timestamped JSON |
| `low_power/speedometer_runner.clj` | Speedometer through Chrome DevTools | Chrome and internet; JSON on stdout; isolated profile cleaned up |

The three `benchmark_*_native.sh` files are compatibility launchers for existing
Homebrew tap build/PGO callers. They forward arguments and environment to the
Clojure implementations and contain no benchmark logic.

## Measurement boundaries

Use the same hardware, software versions, temperature, power settings, corpus,
and background-work conditions for a comparison. Repeat measurements and compare
medians; one faster workload does not establish general application performance.

Babashka starts once, outside measured work. ripgrep and Ctags measure external
process wall time, including process creation. Corpus generation, semantic checks,
and reporting stay outside those windows. Candidate order alternates each sample,
and identical executable paths still receive independent samples.

Git retains the legacy aggregate `user + sys` CPU measurement: `/usr/bin/time`
wraps one Bash payload containing eight Git commands. Babashka startup and corpus
setup are excluded. macOS timing resolution is coarser than the printed decimals.
Git configuration and hooks are isolated, and commits have fixed timestamps.

Vim uses its own `reltime()` measurements. Corpus reload and startup are excluded;
user configuration is disabled. Zero, nonfinite, corrupt, and incomplete samples
fail instead of producing a completed report. Even medians average the middle two
samples. Reports are published atomically only after every workload succeeds.

The new Vim corpus uses a seeded Clojure generator and structured Ruby source.
Its bytes differ from the earlier awk-generated corpus. Reuse the same corpus
for both candidates and rerun both baselines; historical Vim workload timings are
not directly comparable. Reports record corpus SHA-256 hashes and binary metadata.
Historical measurements and raw JSON remain unchanged.

The [4 October 2026 Apple M1 Pro run](results/m1-pro-20261004/README.md) records
all ten entry-point attempts, exact commands, workload results, and four fresh
same-version Vim bottle/native baselines. Eight entry points completed; the two
battery benchmarks required disconnecting AC power. The report also records an
unexplained delay between Speedometer page completion and process exit.

## Vim and native binaries

```sh
bb benchmarks/profile_vim_plugins.clj
RUNS=9 bb benchmarks/profile_vim_plugins_median.clj
VIM_BIN=/opt/homebrew/bin/vim VIMRC_PATH="$PWD/.vimrc" bb benchmarks/profile_vim_plugins.clj

bb benchmarks/benchmark_ripgrep_native.clj /opt/homebrew/bin/rg native /path/to/baseline/rg baseline
bb benchmarks/benchmark_ctags_native.clj /opt/homebrew/bin/ctags native /path/to/baseline/ctags baseline
bb benchmarks/benchmark_git_native.clj /opt/homebrew/bin/git /path/to/baseline/git
VIM_BIN=/opt/homebrew/bin/vim bb benchmarks/vim_bench.clj --bench-only --label native --runs 7
bb benchmarks/vim_bench.clj --compare benchmarks/results/bottle_TIMESTAMP.txt benchmarks/results/native_TIMESTAMP.txt
```

Startup plugin totals sum self time, excluding nested sourced work.
`plugin_start_total_ms` is this sum; `total_startup_ms` is the last elapsed startup
log timestamp. The archived historical chart used inclusive sourcing totals;
nested work overlaps, so those totals are not additive plugin cost.

ripgrep validates file lists and matching-line counts independently before timing.
Ctags requires tag output and equivalent sorted JSON between candidates.
Git requires successful and equivalent workload output. Failed commands abort.

Defaults and overrides:

- ripgrep: `RG_BENCH_REPETITIONS=9`, `RG_BENCH_WARMUPS=2`, `RG_BENCH_CORPUS` for a
  reusable corpus. Existing incomplete corpora are never overwritten.
- Ctags: `CTAGS_BENCH_REPETITIONS=9`, `CTAGS_BENCH_WARMUPS=2`.
- Git: `GIT_BENCH_REPETITIONS=7`, `GIT_BENCH_WARMUPS=2`, or `--repetitions` and
  `--warmups`. Use `pgo-training` after the executable for training workloads.
- Vim: `VIM_BIN`, `VIM_BENCH_CORPUS`, `VIM_BENCH_RESULTS`, `--runs`, and `--label`.

**Running `vim_bench.clj` without `--bench-only` or `--compare` reinstalls Homebrew
Vim and invokes the legacy compiler through `bootstrap/native/`.** Use
`--bench-only` for an already installed binary. Current native builds live in
[homebrew-tap](https://github.com/marianposaceanu/homebrew-tap).

## Battery and browser measurements

The `m4_` names identify the original M4 MacBook Air experiment. Compatible Macs
can run these scripts, but comparisons must stay on the same device. Battery
telemetry measures the whole system, rather than CPU-only energy use.

Select the desired Low Power Mode in **System Settings → Battery**, disconnect
AC power, and keep brightness, battery level, thermals, peripherals, and background
work consistent. The scripts verify settings and never change them. Throughput
checks surround each workload; telemetry checks every sample and rejects an early
or failed OpenSSL exit. Results are saved only after the entire run succeeds.

```sh
bb benchmarks/low_power/m4_low_power_benchmark.clj normal 5
bb benchmarks/low_power/m4_low_power_benchmark.clj low 5
bb benchmarks/low_power/m4_power_benchmark.clj normal
bb benchmarks/low_power/m4_power_benchmark.clj low
bb benchmarks/low_power/speedometer_runner.clj 5
```

Telemetry defaults: 90 seconds idle, 60 seconds warmup, 180 seconds load, samples
every 5 seconds. Use `--help` for duration options. XML plist parsing handles
battery data directly. Macs exposing capacity in `BatteryData` use those fields
when `AppleRaw*` fields are absent; samples record the capacity source. Missing
optional temperature telemetry is recorded as null.

Chrome defaults to `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`;
`CHROME_BIN` overrides it. The browser runner sets the viewport before navigation,
uses a fresh profile and OS-assigned DevTools port, and bounds requests to 30 seconds
and the full run to 15 minutes. Override with `SPEEDOMETER_REQUEST_TIMEOUT_MS` and
`SPEEDOMETER_TIMEOUT_MS`. Disconnects fail pending requests; cleanup terminates
Chrome and removes the profile. Only valid positive scores are accepted.
Standalone Speedometer has no battery-mode requirement.

SHA-256 throughput explicitly uses 8192-byte blocks; OpenSSL's displayed `k`
suffix denotes kB/s. This avoids treating the last column of a version-dependent
default block-size table as the 8192-byte measurement.

## Verification and saved results

```sh
bb test:unit
bb test integration.benchmarks-test
bb bootstrap/checks/check_configs.clj
```

Tests use `clojure.test`, disposable fixtures, short real Vim/ripgrep workloads,
and a Clojure Chrome/DevTools simulator. They cover failure status, sample validation,
self-time accounting, alternating comparisons, battery state, fragmented WebSocket
messages, disconnects, and deadlines. They do not reinstall packages, change power
settings, or run a full browser benchmark. Configuration checks include them.

Generated corpora and text reports are ignored by Git. New telemetry JSON is not
ignored: review its environment and measurements before committing it. For an
absolute entry-point path outside this repository, pass `--config /path/to/dot-files/bb.edn`.
