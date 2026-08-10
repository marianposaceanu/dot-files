---
published: 2026-07-29
visible-date: 29th July 2026
category: Measured performance
eyebrow: Apple Silicon · native builds · measured trade-offs
---
# Native Apple Silicon builds for Vim, ripgrep, Ctags, and Git

Four same-version Homebrew rebuilds, one safety model, and mixed results. Start with Vim, then follow the evidence through ripgrep, Universal Ctags, and Git.

---

## What was optimized

The experiment rebuilt four command-line tools for the exact Apple CPU in the machine:

- Vim with `-O3 -mcpu=native -ffp-contract=fast -flto`;
- ripgrep with Rust's upstream `release-lto` profile and `target-cpu=native`;
- Universal Ctags with `-O3 -mcpu=native`, LTO, and optional PGO;
- Git's main executable and builtins with `-O3 -mcpu=native -flto` and optional PGO.

These are not generic replacements for Homebrew bottles. A bottle is built once for a compatible Apple Silicon baseline and distributed to many Macs. A native build can use the scheduling model and instruction set of one detected generation, such as `apple-m1` or `apple-m4`, but it gives up that portability.

The measurements also come from two machines. The recorded Vim CPU benchmark used an Apple M4. The ripgrep, Ctags, and Git measurements used an M1 Pro. Results should be read within each same-machine, same-version comparison, not as a ranking between those Macs.

## The safety contract shared by every build

Compiler flags are the easy part. Safely replacing a Homebrew-managed executable requires a stricter workflow:

1. Resolve the active `opt` symlink to the exact Cellar keg.
2. Read the installed formula snapshot and verify its source URL and SHA-256.
3. Derive `apple-mN` from the CPU brand and prove that `-mcpu=native` resolves to the same generation. This includes M4 rather than stopping at an M1-M3 allowlist.
4. Build in a controlled environment with the formula's features and dependency paths.
5. Compare architecture, version, optional features, runtime paths, and dynamic-library install names with the installed baseline.
6. Exercise representative behavior before touching the Cellar.
7. Benchmark the candidate against the still-installed executable.
8. Stage and back up on the same filesystem, atomically replace one binary, then verify it again.
9. Restore the binary and original pin state if any step fails.
10. Pin the successful custom build so `brew upgrade` cannot silently overwrite it.

No workflow uses `make install`. Vim, Ctags, and Git replace only their main executable. ripgrep replaces only `rg`. Homebrew remains responsible for the rest of each keg.

## Vim: remove startup work first

Vim is the best place to start because two independent kinds of work were measured. Plugin sourcing affects every launch; native compilation affects CPU-bound work after Vim is running.

Repeated `--startuptime` logs showed that removing unnecessary plugins and lazy-loading command-driven features mattered more than compiler flags:

```chart
Vim plugin sourcing time: lower is better
With vim-polyglot | 36.079 ms | 1000 | Original measured plugin startup total
Without vim-polyglot | 22.105 ms | 613 | 38.7% less plugin sourcing
Lazy-loaded optional plugins | 10.170 ms | 282 | NERDTree and GoldenView moved to `pack/*/opt`
Lightline only | 6.184 ms | 171 | vim-airline and its theme package removed
Without ack.vim; Tabular optional | 3.600 ms | 100 | Search consolidated on fzf.vim and ripgrep
Fugitive optional | 3.325 ms | 92 | Final measured plugin sourcing total
```

The total fell from 36.079 ms to 3.325 ms, about 90.8% less plugin startup work. That is a 10.85x ratio between the first and final plugin totals, not a claim that the complete editor launches 10.85x faster. Vim itself, dynamic libraries, the terminal, filesystem caches, and the rest of `.vimrc` remain part of total startup.

The lazy-loading boundary is the command that first needs a plugin:

```vim
nnoremap <C-n> :packadd nerdtree <Bar> NERDTreeToggle<CR>

augroup tabular_lazy
  autocmd!
  autocmd CmdUndefined Tabularize packadd tabular
augroup END

augroup fugitive_lazy
  autocmd!
  autocmd CmdUndefined Git,G,Gstatus,Gblame,Glog,Gclog,Gwrite,Gread,Gdiffsplit,Gvdiffsplit,GBrowse packadd fugitive | packadd vim-rhubarb
augroup END
```

Only after reducing startup work did the executable build become worth testing. On the M4, the native binary improved CPU-heavy regex and Vimscript workloads while a memory-bound sort moved much less:

```chart
Vim native elapsed time relative to the bottle: lower is better
Regex scan NFA | 0.0297 s | 820 | Bottle 0.0362 s; 17.9% less elapsed time; 1.22x faster
Regex replace NFA | 0.0703 s | 867 | Bottle 0.0811 s; 13.3% less elapsed time; 1.15x faster
Buffer sort | 0.2497 s | 957 | Bottle 0.2609 s; 4.3% less elapsed time; 1.04x faster
Vimscript loop, 500k | 0.4003 s | 814 | Bottle 0.4915 s; 18.6% less elapsed time; 1.23x faster
Regex on Ruby code | 0.0187 s | 862 | Bottle 0.0217 s; 13.8% less elapsed time; 1.16x faster
```

The defensible result is narrow: 15-23% speedups in these CPU-bound operations, and about 4% for the memory-bound sort. Native compilation complements startup cleanup; it cannot compensate for loading plugins that should not run.

## ripgrep: PGO helped one trained workload

ripgrep already ships as an efficient Rust program with a strong release profile. Its native/LTO build was effectively neutral against the Homebrew ARM64 Tahoe bottle on the M1 Pro. Most differences were around 1%, below the useful resolution of these short runs. Unicode regex improved by 2%.

The optional PGO workflow builds an instrumented executable, trains literal, regex, Unicode, PCRE2, traversal, and 1/2/4/8/default-thread workloads, merges the LLVM profiles, then performs a clean final LTO build.

```chart
ripgrep PGO elapsed time relative to the bottle: lower is better
Literal, one thread | 27.20 ms | 989 | Bottle 27.52 ms; 1.1% faster
Regex, one thread | 27.96 ms | 986 | Bottle 28.35 ms; 1.4% faster
Unicode regex | 83.79 ms | 895 | Bottle 93.67 ms; 10.5% faster
PCRE2 lookaround | 496.26 ms | 986 | Bottle 503.33 ms; 1.4% faster
Literal, four threads | 14.37 ms | 975 | Bottle 14.75 ms; 2.5% faster
Literal, eight threads | 11.79 ms | 977 | Bottle 12.08 ms; 2.3% faster
Literal, default threads | 11.71 ms | 984 | Bottle 11.90 ms; 1.6% faster
5,000-file traversal | 12.02 ms | 1000 | Bottle 11.56 ms; 3.9% slower
```

PGO materially improved the trained Unicode-regex workload. Most other changes were small, and traversal regressed. Thread count had a larger effect on literal search than PGO: automatic threading was 2.32x faster than the PGO build's one-thread median on this corpus.

The result is not “custom ripgrep is faster.” It is that PGO can help a representative hot path, while the standard bottle remains a very strong general default.

## Universal Ctags: the clearest repeatable gain

Universal Ctags 6.2.1 produced the strongest broad result on the M1 Pro. The script requires exact parity with the bottle's optional feature set and linkage to jansson, libyaml, PCRE2, system XML, and system iconv. It then checks deterministic C, Ruby, JSON, and YAML tag output before comparing performance.

The plain native/LTO build improved each language-specific parser:

```chart
Ctags native/LTO elapsed time relative to the bottle: lower is better
C parser | 71.68 ms | 894 | Bottle 80.19 ms; 10.6% faster
Ruby parser | 41.91 ms | 900 | Bottle 46.58 ms; 10.0% faster
JSON and YAML parsers | 63.34 ms | 942 | Bottle 67.22 ms; 5.8% faster
Representative mixed parsers | 27.01 ms | 995 | Bottle 27.13 ms; 0.5% faster, effectively neutral
```

PGO then improved the already-native build on the trained parser workloads:

```chart
Ctags PGO elapsed time relative to native/LTO: lower is better
C parser | 63.28 ms | 875 | Native/LTO 72.30 ms; 12.5% faster
Ruby parser | 37.73 ms | 913 | Native/LTO 41.33 ms; 8.7% faster
JSON and YAML parsers | 60.06 ms | 952 | Native/LTO 63.09 ms; 4.8% faster
Representative mixed parsers | 26.72 ms | 1000 | Native/LTO 26.69 ms; 0.1% slower, effectively neutral
```

These are separate interleaved runs, so their absolute medians should not be chained into one synthetic bottle-to-PGO percentage. The direct conclusions are enough: native/LTO helped the language-specific parsers, and PGO added another workload-specific improvement.

## Git: same contract, no measured win

Git 2.55.0 was the most demanding compatibility case and the least exciting benchmark result. Homebrew's main `git` executable also implements its builtins through symlinks such as `git-add` and `git-status`, so replacing that one file optimizes builtins without claiming that external helpers were rebuilt.

The candidate must preserve Git's CommonCrypto choice, PCRE2 and gettext linkage, system libcurl and libiconv, SHA implementations, shell path, executable path, documentation paths, and `FALLBACK_RUNTIME_PREFIX`. Smoke tests create temporary repositories and exercise commits, branches, PCRE2 grep, fsck, garbage collection, bundles, and clones without reading global Git configuration.

```chart
Git aggregate benchmark CPU time: lower is better
Homebrew bottle | 0.070 s | 1000 | status, diff, grep, log, traversal, fsck, and commit-graph verification
Native/LTO | 0.070 s | 1000 | No measurable change versus the bottle
Native/LTO plus PGO | 0.070 s | 1000 | No measurable change versus native/LTO
```

The native and PGO builds were neutral at the benchmark's 0.01-second reporting resolution. That is still useful evidence: a safe, reproducible build workflow does not imply that installing its output is worthwhile for every tool.

## What LTO and PGO contribute

**Link-Time Optimization (LTO)** keeps compiler information through the link stage so optimization can cross source-file and library boundaries. It can inline across translation units and remove code that is unused once the complete executable is visible. LTO costs build time and memory but adds no profiling instrumentation to the final binary.

**Profile-Guided Optimization (PGO)** is a two-stage process. An instrumented build records which functions and branches the training workload uses. A second build consumes the merged profile to improve hot-path layout, inlining, and branch decisions. The final executable has no training overhead.

PGO's weakness is also its purpose: it specializes for observed behavior. Ctags' parser workloads and ripgrep's Unicode regex benefited. ripgrep traversal regressed, Ctags' mixed corpus was neutral, and Git did not move. Training must resemble real use, and the final decision still belongs to an independent benchmark.

## Rebuild and restore commands

Each script supports a bottle restoration path because the Homebrew receipt continues to describe the formula installation after a binary-only replacement.

```sh
# Vim
./bootstrap/native/compile_vim_native.sh
brew unpin vim && brew reinstall vim

# ripgrep
./bootstrap/native/compile_ripgrep_native.sh --pgo
brew unpin ripgrep && brew reinstall ripgrep

# Universal Ctags
brew install docutils llvm
./bootstrap/native/compile_ctags_native.sh --pgo
brew unpin universal-ctags && brew reinstall universal-ctags

# Git
brew install llvm pkgconf
./bootstrap/native/compile_git_native.sh --pgo
brew unpin git && brew reinstall git
```

After a formula upgrade, unpin and upgrade first, inspect the changed formula contract, then rerun the corresponding script. The Git workflow intentionally stops until its exact version and source contract are updated.

## Where the evidence lands

The experiment produced four different answers:

- **Vim:** removing plugin startup work was the largest everyday improvement; native compilation helped CPU-bound microbenchmarks.
- **ripgrep:** native/LTO was neutral; PGO materially helped Unicode regex but not traversal.
- **Universal Ctags:** native/LTO and PGO both improved trained language parsers.
- **Git:** native/LTO and PGO preserved behavior but did not measurably improve the aggregate workload.

The general lesson is not to rebuild every Homebrew formula. It is to make optimization falsifiable: preserve the package contract, compare the same version, train PGO on representative work, publish regressions beside gains, and keep a one-command route back to the bottle.

The implementation lives in [`bootstrap/`](https://github.com/marianposaceanu/dot-files/tree/main/bootstrap), [`benchmarks/`](https://github.com/marianposaceanu/dot-files/tree/main/benchmarks), and the native-build documentation in the [dot-files README](https://github.com/marianposaceanu/dot-files#what-lto-and-pgo-mean).
