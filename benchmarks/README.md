# Benchmarks

Run these Bash entry points from the repository root. They measure local
workloads; results depend on the hardware, software version, temperature,
power source, and other running processes. Close competing workloads, keep the
conditions consistent, and compare repeated runs of the same software version.
A faster median on one workload does not imply a faster application overall.

## Scripts and dependencies

| Script | Purpose | Dependencies and output |
| --- | --- | --- |
| `profile_vim_plugins.sh` | One startup profile with per-file and plugin self times | Vim or Neovim; repository `.vimrc` and initialized plugins; prints a retained temporary log path |
| `profile_vim_plugins_median.sh` | Repeated startup profiles and medians | Same; `RUNS=7` by default; temporary logs removed after each successful run |
| `generate_vim_startup_chart.sh` | Text comparison of archived startup profiles | awk; reads checked-in `vim_startup_profile_*.txt`, without running Vim |
| `vim_bench.sh` | Regex, replacement, sort, and Vimscript workloads | Vim, Python 3; corpus and timestamped results below this directory; default seven runs |
| `benchmark_ripgrep_native.sh` | Search, Unicode, PCRE2, thread scaling, and traversal | ripgrep with PCRE2, Python 3; persistent deterministic corpus in `${TMPDIR:-/tmp}`; Markdown on stdout |
| `benchmark_ctags_native.sh` | C, Ruby, JSON, YAML, and mixed parsing | Universal Ctags, Python 3; disposable corpus; Markdown on stdout |
| `benchmark_git_native.sh` | Git CPU workloads and optional PGO training | Git with PCRE2, `/usr/bin/time`; disposable repository; Markdown on stdout |
| `m4_low_power_benchmark.sh` | SHA-256 throughput and Speedometer 3.1 | macOS, OpenSSL, Node.js 22+, Chrome; timestamped text in `results/` |
| `m4_power_benchmark.sh` | Idle, warmup, and loaded battery telemetry | macOS AppleSmartBattery telemetry, OpenSSL, Python 3; timestamped JSON in `results/` |
| `speedometer_runner.sh` | Standalone Speedometer 3.1 through Chrome DevTools | Node.js 22+, Chrome, internet access; JSON on stdout; isolated Chrome profile removed on exit |

All entry points use `.sh`. Structured data and subprocess orchestration still
use embedded Python 3 where appropriate, and browser automation uses embedded
Node.js. Renaming the entry points does not remove those runtime dependencies.

## Vim startup

```sh
./benchmarks/profile_vim_plugins.sh
RUNS=9 ./benchmarks/profile_vim_plugins_median.sh
VIM_BIN=/opt/homebrew/bin/vim VIMRC_PATH="$PWD/.vimrc" \
  ./benchmarks/profile_vim_plugins.sh
./benchmarks/generate_vim_startup_chart.sh
```

Startup profiling loads the selected config and its plugins. Plugin totals sum
Vim's **self** time (third startup-log column), excluding time spent sourcing
nested files. `plugin_start_total_ms` reports this sum; `total_startup_ms` is the
last elapsed timestamp, including the rest of startup.

Archived text profiles and the chart contain earlier **inclusive** sourcing
measurements. Nested times overlap, so those totals are not additive measures
of plugin cost. The chart labels this limitation. Historical measurements stay
unchanged; rerun the profilers for current self-time measurements.

## Binary comparisons

Specify absolute executable paths to avoid accidentally comparing the same
binary through PATH. Use matching versions, and save stdout if you want a report.
Comparison samplers keep separate measurements even when paths are identical.

```sh
./benchmarks/benchmark_ripgrep_native.sh /opt/homebrew/bin/rg native /path/to/baseline/rg baseline
./benchmarks/benchmark_ctags_native.sh /opt/homebrew/bin/ctags native /path/to/baseline/ctags baseline
./benchmarks/benchmark_git_native.sh /opt/homebrew/bin/git /path/to/baseline/git
VIM_BIN=/opt/homebrew/bin/vim ./benchmarks/vim_bench.sh --bench-only --label native --runs 7
./benchmarks/vim_bench.sh --compare benchmarks/results/bottle_TIMESTAMP.txt benchmarks/results/native_TIMESTAMP.txt
```

ripgrep checks file lists and matching-line counts against the corpus before
measuring. Empty, incorrect, or failing search output aborts the benchmark;
configuration and ignore files are disabled. `RG_BENCH_CORPUS` selects a reusable
corpus; an existing incomplete tree is never overwritten. Defaults:
`RG_BENCH_REPETITIONS=9`, with two warmups.

Ctags defaults to `CTAGS_BENCH_REPETITIONS=9` and `CTAGS_BENCH_WARMUPS=2`.
Git defaults to `GIT_BENCH_REPETITIONS=7` and `GIT_BENCH_WARMUPS=2`, also available
as `--repetitions` and `--warmups`. Git isolates configuration and compares
workload output and exit status. Its CPU time uses macOS `/usr/bin/time`
resolution; extra printed decimals do not improve the measurement precision.

Vim disables user configuration for its workload runs. Failed workloads or
invalid timing samples abort without publishing a completed result file.
Even-sized samples use the average of the middle two sorted values.

**Running `vim_bench.sh` without `--bench-only` or `--compare` reinstalls Homebrew
Vim and invokes the legacy native compiler through `bootstrap/native/`.** This
changes the installed Vim. Use `--bench-only` to measure an already installed
binary. Current native builds are maintained in
[homebrew-tap](https://github.com/marianposaceanu/homebrew-tap).

## Battery and browser measurements

The `m4_` names describe the original M4 MacBook Air experiment; the scripts can
run on other compatible Macs. These are whole-system measurements, not direct
CPU-only energy measurements. Compare modes on the same hardware and keep
brightness, battery level, peripherals, thermals, and background work consistent.

Select the requested Low Power Mode under **System Settings → Battery**, then
disconnect AC power. The scripts verify the battery mode and power state;
they never change settings. Throughput checks surround workloads; telemetry
checks every sample and rejects a stopped or failed OpenSSL workload.

```sh
./benchmarks/m4_low_power_benchmark.sh normal 5
./benchmarks/m4_low_power_benchmark.sh low 5
./benchmarks/m4_power_benchmark.sh normal
./benchmarks/m4_power_benchmark.sh low
./benchmarks/speedometer_runner.sh 5
```

Telemetry defaults: 90 seconds idle, 60 seconds warmup, 180 seconds load, samples
every 5 seconds. See `m4_power_benchmark.sh --help` for duration overrides.
`CHROME_BIN` overrides the Chrome executable. The browser runner bounds each
DevTools request to 30 seconds and the entire run to 15 minutes; override with
`SPEEDOMETER_REQUEST_TIMEOUT_MS` and `SPEEDOMETER_TIMEOUT_MS`. Disconnects reject
pending requests, and cleanup terminates Chrome and removes its temporary profile.
Only valid positive Speedometer results are accepted.

The throughput script streams its text log to `results/`; a failed run can leave
a partial log. A final `finished=` line and a successful exit are required for a
complete run. Standalone Speedometer has no battery-mode requirement.

## Results and verification

Checked-in `results/` reports and raw JSON record historical experiments; they
are not current baselines or promises of performance. Historical numbers are
preserved. Generated Vim corpora and new text result logs are ignored by Git.
New telemetry JSON is not ignored; review it before committing.

```sh
bash test/benchmarks_test.sh
bb bootstrap/checks/check_configs.clj
```

Regression checks require Python 3 and Node.js 22+; installed Vim and ripgrep
are used for optional smoke runs. The checks use disposable fixtures and short runs.
They do not reinstall packages, change power settings, or run the full browser
benchmark. Configuration checks also validate shell syntax.
