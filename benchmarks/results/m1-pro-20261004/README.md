# Apple M1 Pro benchmark run — 4 October 2026

All ten Clojure entry points were attempted on the local Mac: eight completed and two were blocked by the battery-power requirement. Benchmarks ran sequentially; no installed package or power setting was changed. The benchmark implementations were at commit `fe66aa7`.

The commands recorded below are the original commands used for this run. The current battery and Speedometer entry points live under `benchmarks/low_power/`; see [the benchmark guide](../../README.md) for runnable commands.

## Artifact review and cleanup

Only five unused loose startup captures were removed, after confirming that each is byte-identical to its retained archive member and has no active references:

- `benchmarks/vim_startup_profile_after_core_tweaks.txt`
- `benchmarks/vim_startup_profile_after_perf_tweaks.txt`
- `benchmarks/vim_startup_profile_before_perf_tweaks.txt`
- `benchmarks/vim_startup_profile_latest.txt`
- `benchmarks/vim_startup_profile_lightline_trial.txt`

The six `.txt` inputs used by `generate_vim_startup_chart.clj` remain. The `.tar.gz` archive and checksum remain because they preserve the legacy implementations, original regression harness, historical captures, and results used by existing documentation. All 28 members were byte-verified against commit `b8aad75`, and the archive checksum was verified. Historical M4 reports and telemetry JSON were retained (the JSON captures are now gzip-compressed). `docs/robots.txt` is an active website file and was retained.

Proof of preserved bytes and hashes: [cleanup-audit.json](cleanup-audit.json). The fresh Vim reports below are needed baselines and were retained. Generated corpora and raw process logs remain local; they are not included in the commit.

## Environment and measurement protocol

- MacBookPro18,3; Apple M1 Pro; 10 CPU cores (8 performance, 2 efficiency); 16 GB RAM.
- macOS 27.0.1 (26A434); AC power, battery charging; Low Power Mode setting 0.
- Babashka 1.13.225; ripgrep 15.2.0 with PCRE2; Universal Ctags 6.2.1; Git 2.56.0; OpenSSL 4.0.3; Chrome 154.0.8037.93.
- The stock Homebrew bottle and installed native Vim both use Vim 9.2.1150. Native metadata identifies `native-apple-m1` with `-O3 -mcpu=apple-m1`. They have different build configurations/features, so this is a comparison of complete builds, not an isolated test of compiler flags.
- An independently downloaded stock bottle was SHA-256 verified, extracted into a temporary directory, and had its library-prefix placeholders relocated there. It was not installed over the native Vim.
- Four Vim sessions used 30 samples each in bottle/native/native/bottle order. Reload and startup are excluded from Vim timings. Both candidates used the same seeded `vim-v2` corpus; both SHA-256 hashes match across all four reports.
- ripgrep/Ctags measure process wall time; Git reports aggregate CPU time; startup profiles use Vim log timings. Defaults for their sample counts and warmups were retained. `caffeinate -i` prevented idle sleep during the sequential run.
- Ordinary background activity was not otherwise controlled. No battery-mode comparison is available from this run.

Detailed build metadata and hashes: [vim-builds.json](vim-builds.json). Runtime versions and power-state snapshots: [environment.json](environment.json).

## All ten entry points

| Entry point | Status | Result / reason |
| --- | --- | --- |
| `profile_vim_plugins.clj` | Passed | Full startup capture retained in startup-raw.log; plugin/file self-time report in results.json. |
| `profile_vim_plugins_median.clj` | Passed | 7 runs; median total startup 24.529 ms; plugin self-time total 4.272 ms. |
| `generate_vim_startup_chart.clj` | Passed | Historical inclusive totals 36.079 → 3.325 ms. This renders archived captures; it is not a fresh M1 Pro performance result. |
| `benchmark_ripgrep_native.clj` | Passed | 9 workloads, 9 samples after 2 warmups; median range 8.94–503.32 ms. |
| `benchmark_ctags_native.clj` | Passed | 4 workloads, 9 samples after 2 warmups; median range 27.33–75.23 ms. |
| `benchmark_git_native.clj` | Passed | 7 samples after 2 warmups; median aggregate user + sys CPU time 0.170000 s. |
| `vim_bench.clj` | Passed | Four fresh sessions, 30 samples per workload per session; both same-version bottle/native comparisons passed. |
| `m4_low_power_benchmark.clj` | Blocked (exit 1) | Mac was charging on AC. Disconnect AC power before benchmarking battery modes. No throughput/browser battery-mode result was generated. |
| `m4_power_benchmark.clj` | Blocked (exit 1) | Mac was charging on AC. Disconnect AC power before benchmarking battery modes. No idle/load battery energy result was generated. |
| `speedometer_runner.clj` | Passed | Speedometer 3.1: 39.2 ± 8.0, valid=true, 5 iterations, viewport 1200×900; progress 290/290. |

## Fresh Vim comparison baselines

Each row below is a median of 30 measurements. Speedup is bottle time / native time. The second pair reverses candidate order. These are fresh `vim-v2` baselines; the May 2026 M4/awk-corpus timings are not directly comparable.

### Pair A

| Workload | Bottle (s) | Native (s) | Speedup |
| --- | ---: | ---: | ---: |
| Regex scan NFA (100k lines, no substitution) | 0.042993 | 0.032811 | 1.31x |
| Regex and replacement NFA (100k lines) | 0.106166 | 0.082187 | 1.29x |
| Buffer sort (100k lines) | 0.327487 | 0.312346 | 1.05x |
| Vimscript while loop (500k iterations) | 0.643271 | 0.597704 | 1.08x |
| Regex on Ruby source (complex alternation) | 0.023592 | 0.019277 | 1.22x |

### Pair B

| Workload | Bottle (s) | Native (s) | Speedup |
| --- | ---: | ---: | ---: |
| Regex scan NFA (100k lines, no substitution) | 0.042933 | 0.032954 | 1.30x |
| Regex and replacement NFA (100k lines) | 0.106291 | 0.082322 | 1.29x |
| Buffer sort (100k lines) | 0.331415 | 0.311936 | 1.06x |
| Vimscript while loop (500k iterations) | 0.644997 | 0.601875 | 1.07x |
| Regex on Ruby source (complex alternation) | 0.023622 | 0.019220 | 1.23x |

Canonical baseline reports:

- [vim-bottle-a_20261003T224328234Z.txt](vim-baselines/vim-bottle-a_20261003T224328234Z.txt)
- [vim-bottle-b_20261003T224507866Z.txt](vim-baselines/vim-bottle-b_20261003T224507866Z.txt)
- [vim-native-a_20261003T224400427Z.txt](vim-baselines/vim-native-a_20261003T224400427Z.txt)
- [vim-native-b_20261003T224432646Z.txt](vim-baselines/vim-native-b_20261003T224432646Z.txt)

## Native binary workload results

### ripgrep

| Workload | Median | Minimum | Maximum |
| --- | ---: | ---: | ---: |
| literal, one thread | 28.50 ms | 28.25 ms | 29.64 ms |
| literal, two threads | 19.20 ms | 19.12 ms | 19.42 ms |
| literal, four threads | 14.79 ms | 14.37 ms | 14.88 ms |
| literal, eight threads | 12.02 ms | 11.45 ms | 13.35 ms |
| literal, default threads | 11.41 ms | 11.10 ms | 12.48 ms |
| regex, one thread | 29.15 ms | 29.02 ms | 29.49 ms |
| Unicode regex, one thread | 93.65 ms | 93.21 ms | 94.08 ms |
| PCRE2 lookaround, one thread | 503.32 ms | 502.33 ms | 504.82 ms |
| 5,000-file traversal | 8.94 ms | 8.05 ms | 10.28 ms |

### Universal Ctags

| Workload | Median | Minimum | Maximum |
| --- | ---: | ---: | ---: |
| C parser | 75.23 ms | 74.57 ms | 75.97 ms |
| Ruby parser | 42.58 ms | 42.45 ms | 43.31 ms |
| JSON and YAML parsers | 65.19 ms | 65.11 ms | 68.04 ms |
| representative mixed parsers | 27.33 ms | 27.31 ms | 27.97 ms |

### Git

`/opt/homebrew/bin/git	median CPU seconds: 0.170000`

## Speedometer and completion delay

The page reported score **39.2 ± 8.0** with five iteration scores: 27.713, 41.577, 41.644, 42.562, 42.547. The first iteration was substantially slower than the other four; the confidence interval is wide, so this single session is not evidence of a stable cross-build browser speedup.

The recorded page-completion timestamp is 23.069 seconds after its start. The controller did not return until 331.855 seconds after launch. The additional roughly 308.8 seconds occurred after reported page completion; its exact cause was not established. A later read-only DevTools progress query found no active endpoint. No benchmark was interrupted, and the process eventually returned exit 0. This completion delay remains an observation for follow-up.

## Commands used

Bottle preparation:

```sh
HOMEBREW_NO_AUTO_UPDATE=1 brew info --json=v2 homebrew/core/vim
HOMEBREW_NO_AUTO_UPDATE=1 brew fetch --bottle-tag=arm64_golden_gate homebrew/core/vim
```

The download was verified against Homebrew SHA-256 `1714ffe420e510f8e9ed57d848c8ad5220286dd6966dacab6d0aefa2f6d9397c` and extracted outside the repository. Exact relocation commands and the original/relocated executable hashes are recorded in [vim-builds.json](vim-builds.json). Recovered setup errors are recorded in [preparation.json](preparation.json): mutually exclusive fetch options, a `brew --cache` tag error, and the unrelocated bottle’s initial `dyld` `_BC` error. All were resolved before the measured runs.

Actual benchmark invocations, in order (from the repository root):

**startup-single** — exit 0, 0.094 s process wall time.

```sh
VIM_BIN=/opt/homebrew/bin/vim /opt/homebrew/bin/bb benchmarks/profile_vim_plugins.clj
```

**startup-median** — exit 0, 0.341 s process wall time.

```sh
VIM_BIN=/opt/homebrew/bin/vim RUNS=7 /opt/homebrew/bin/bb benchmarks/profile_vim_plugins_median.clj
```

**historical-chart** — exit 0, 0.030 s process wall time.

```sh
/opt/homebrew/bin/bb benchmarks/generate_vim_startup_chart.clj
```

**ripgrep** — exit 0, 31.266 s process wall time.

```sh
/opt/homebrew/bin/bb benchmarks/benchmark_ripgrep_native.clj /opt/homebrew/bin/rg native-m1-pro
```

**ctags** — exit 0, 3.397 s process wall time.

```sh
/opt/homebrew/bin/bb benchmarks/benchmark_ctags_native.clj /opt/homebrew/bin/ctags native-m1-pro
```

**git** — exit 0, 4.366 s process wall time.

```sh
/opt/homebrew/bin/bb benchmarks/benchmark_git_native.clj /opt/homebrew/bin/git
```

**vim-bottle-a** — exit 0, 35.359 s process wall time.

```sh
VIM_BENCH_CORPUS=/Users/marian/dot-files/benchmarks/corpus/vim-v2 VIM_BENCH_RESULTS=/Users/marian/dot-files/benchmarks/results/m1-pro-20261004/vim-baselines VIM_BIN=/var/folders/ns/q3nvc5y96f36dv4sl8vh5cv80000gn/T/dotfiles-vim-bottle-m1-pro-e4vme4ju/vim/9.2.1150/bin/vim /opt/homebrew/bin/bb benchmarks/vim_bench.clj --bench-only --label vim-bottle-a --runs 30
```

**vim-native-a** — exit 0, 32.190 s process wall time.

```sh
VIM_BENCH_CORPUS=/Users/marian/dot-files/benchmarks/corpus/vim-v2 VIM_BENCH_RESULTS=/Users/marian/dot-files/benchmarks/results/m1-pro-20261004/vim-baselines VIM_BIN=/opt/homebrew/bin/vim /opt/homebrew/bin/bb benchmarks/vim_bench.clj --bench-only --label vim-native-a --runs 30
```

**vim-native-b** — exit 0, 32.219 s process wall time.

```sh
VIM_BENCH_CORPUS=/Users/marian/dot-files/benchmarks/corpus/vim-v2 VIM_BENCH_RESULTS=/Users/marian/dot-files/benchmarks/results/m1-pro-20261004/vim-baselines VIM_BIN=/opt/homebrew/bin/vim /opt/homebrew/bin/bb benchmarks/vim_bench.clj --bench-only --label vim-native-b --runs 30
```

**vim-bottle-b** — exit 0, 35.218 s process wall time.

```sh
VIM_BENCH_CORPUS=/Users/marian/dot-files/benchmarks/corpus/vim-v2 VIM_BENCH_RESULTS=/Users/marian/dot-files/benchmarks/results/m1-pro-20261004/vim-baselines VIM_BIN=/var/folders/ns/q3nvc5y96f36dv4sl8vh5cv80000gn/T/dotfiles-vim-bottle-m1-pro-e4vme4ju/vim/9.2.1150/bin/vim /opt/homebrew/bin/bb benchmarks/vim_bench.clj --bench-only --label vim-bottle-b --runs 30
```

**vim-comparison-a** — exit 0, 0.032 s process wall time.

```sh
/opt/homebrew/bin/bb benchmarks/vim_bench.clj --compare /Users/marian/dot-files/benchmarks/results/m1-pro-20261004/vim-baselines/vim-bottle-a_20261003T224328234Z.txt /Users/marian/dot-files/benchmarks/results/m1-pro-20261004/vim-baselines/vim-native-a_20261003T224400427Z.txt
```

**vim-comparison-b** — exit 0, 0.031 s process wall time.

```sh
/opt/homebrew/bin/bb benchmarks/vim_bench.clj --compare /Users/marian/dot-files/benchmarks/results/m1-pro-20261004/vim-baselines/vim-bottle-b_20261003T224507866Z.txt /Users/marian/dot-files/benchmarks/results/m1-pro-20261004/vim-baselines/vim-native-b_20261003T224432646Z.txt
```

**battery-throughput** — exit 1, 0.057 s process wall time.

```sh
/opt/homebrew/bin/bb benchmarks/m4_low_power_benchmark.clj normal 5
```

**battery-telemetry** — exit 1, 0.047 s process wall time.

```sh
/opt/homebrew/bin/bb benchmarks/m4_power_benchmark.clj normal
```

**speedometer** — exit 0, 331.855 s process wall time.

```sh
/opt/homebrew/bin/bb benchmarks/speedometer_runner.clj 5
```

The exact command vectors, environment overrides, start/finish times, exit codes, and process wall times are also preserved in [commands.json](commands.json). The original raw stdout/stderr remains locally under ignored `raw/`; durable benchmark output is in [results.json](results.json). The transient DevTools WebSocket endpoint was omitted from durable results.

## Verification

```sh
bb test
bb bootstrap/checks/check_configs.clj
git diff --check
```

- 43 tests, 268 assertions, zero failures or errors.
- All configuration checks passed. Existing Homebrew Ruby missing-extension warnings were collected at the end; they are environment issues, independent of these measurements.
- The historical chart ran successfully after cleanup, and all four new Vim reports share both corpus hashes.
- Archive checksum and all original archive members verified. No source data or baseline was discarded.
- Eight benchmark entry points completed; two could not run on AC. No battery energy/throughput numbers were inferred or substituted.

Verification summary: [verification.json](verification.json). Complete fresh startup source: [startup-raw.log](startup-raw.log).
