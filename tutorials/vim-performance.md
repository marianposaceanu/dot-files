---
published: 2026-07-29
visible-date: 29th July 2026
category: Measured performance
eyebrow: Vim performance · measured and reproducible
---
# Making Vim faster: less startup work and a native Apple Silicon build

Two independent optimizations: reduce plugin work on every launch, then rebuild Vim for the local Apple CPU. The measurements matter more than either technique.

---

## Start with a repeatable measurement

Vim already exposes startup timing through `--startuptime`. The repository wraps it in two scripts: one shows the slowest sourced files and per-plugin totals, while the other runs the same launch repeatedly and reports medians.

```sh
./benchmarks/profile_vim_plugins.sh
RUNS=7 ./benchmarks/profile_vim_plugins_median.sh
```

The median script records two different values:

- `plugin_start_total_ms` is the accumulated sourcing time under `.vim/pack/bundles/start`.
- `total_startup_ms` is the elapsed time at the final line of Vim's startup log.

That distinction prevents a common benchmarking mistake. A 10x reduction in plugin sourcing does not mean the complete editor launches 10x faster: Vim itself, the terminal, dynamic libraries, file-system caches, and the rest of `.vimrc` still contribute to total startup.

Use the same command, Vim binary, configuration, launch mode, and number of repetitions for every comparison. Change one thing at a time and keep the result only when the median moves by more than normal run-to-run noise.

## Remove work before optimizing code

The largest gains did not come from compiler flags. They came from loading less code during startup.

```text
+---------------------------------------------------------------------------------------+
| VIM STARTUP IMPROVEMENT MAP (plugin_start_total ms; lower is better)                  |
+---------------------------------------------------------------------------------------+
| with_polyglot                      36.079 ms  (10.85x vs best) [####################] |
| without_polyglot                   22.105 ms   (6.65x vs best) [############........] |
| after_lazyload_opt_plugins         10.170 ms   (3.06x vs best) [######..............] |
| lightline_only                      6.184 ms   (1.86x vs best) [###.................] |
| after_ack_removal_tabular_opt       3.600 ms   (1.08x vs best) [##..................] |
| after_fugitive_opt                  3.325 ms   (1.00x best)    [##..................] |
|                                                                                       |
| Overall improvement: 36.079 ms -> 3.325 ms  (~10.85x lower plugin startup load)       |
+---------------------------------------------------------------------------------------+
```

The sequence was deliberately incremental:

1. Remove `vim-polyglot`, whose broad language bundle duplicated capabilities that were not needed on every launch.
2. Move heavy interactive plugins such as NERDTree and GoldenView from `pack/*/start` to `pack/*/opt`.
3. Replace vim-airline and its theme package with the smaller lightline status line.
4. Remove `ack.vim`, because `fzf.vim` and ripgrep already provide the search workflow.
5. Move Tabular and fugitive to optional packages and load them on their first command.
6. Move local buffer helpers to optional packages and remove an unused rename plugin.

The final plugin sourcing total is 3.325 ms, down from 36.079 ms. That is about 90.8% less plugin startup work.

## Lazy-load at the command boundary

Vim packages already provide the required mechanism: directories under `pack/*/opt` stay unloaded until `:packadd` runs. The useful boundary is the command or key that first needs the plugin.

NERDTree loads only when its toggle is pressed:

```vim
nnoremap <C-n> :packadd nerdtree <Bar> NERDTreeToggle<CR>
```

Commands that do not exist yet can trigger an optional package through `CmdUndefined`:

```vim
augroup tabular_lazy
  autocmd!
  autocmd CmdUndefined Tabularize packadd tabular
augroup END

augroup fugitive_lazy
  autocmd!
  autocmd CmdUndefined Git,G,Gstatus,Gblame,Glog,Gclog,Gwrite,Gread,Gdiffsplit,Gvdiffsplit,GBrowse packadd fugitive | packadd vim-rhubarb
augroup END
```

For a mapping that needs setup and execution together, a small function keeps the sequence explicit:

```vim
function! s:ToggleGoldenView() abort
  packadd GoldenView.Vim
  execute 'GoldenViewToggle'
endfunction
nnoremap <leader>gv :call <SID>ToggleGoldenView()<CR>
```

Lazy-loading is not free complexity. Keep a plugin in `start` when it is tiny, required for every editing session, or must define behavior before the first buffer event. Move it to `opt` only when the measured startup cost and a clear activation boundary justify it.

## Add guardrails for expensive files

Startup is only one part of perceived speed. Large files can spend much more time in syntax highlighting and cursor-line redraw than in launching Vim. The configuration marks files over 1 MiB before reading them, then disables syntax and `cursorline` for that buffer:

```vim
augroup large_file_perf
  autocmd!
  autocmd BufReadPre * if getfsize(expand('%:p')) > 1024 * 1024 | let b:large_file = 1 | endif
  autocmd BufReadPost * if exists('b:large_file') | setlocal syntax=OFF nocursorline | endif
augroup END
```

The regex engine remains on `re=0`, which lets Vim choose the engine per pattern rather than forcing one implementation globally.

## Rebuild Vim only after reducing startup work

Once configuration work was removed, the remaining experiment was the executable itself. Homebrew's normal build environment prioritizes a portable bottle. The native script instead compiles the exact source version recorded in the active Homebrew formula with:

- `-O3` for more aggressive inlining and loop optimization;
- `-mcpu=native` to target the detected Apple generation rather than generic ARM64;
- `-ffp-contract=fast` to permit fused multiply-add operations where applicable;
- `-flto` for whole-program optimization at link time.

```sh
./bootstrap/compile_vim_native.sh
```

The script is intentionally more than a compiler command. It verifies the formula's source URL and SHA-256, preserves Homebrew's Vim features and dynamic Perl, Python, Ruby, and Lua paths, tests all four interpreters, checks ARM64 architecture and code signing, stages the candidate in the same Cellar directory, and atomically replaces only the `vim` executable. A failure restores the prior binary and original Homebrew pin state.

`-mcpu=native` is validated at build time and resolves to the current CPU family, such as `apple-m1` or `apple-m4`. The resulting binary is intentionally machine-specific and should not be copied to a different Mac.

## What the native build improved

The recorded native-build comparison was run on an Apple M4 with the same Vim version and representative CPU-bound Vimscript operations:

```text
+---------------------------------------------------------------------------------------+
| VIM NATIVE BUILD  (bottle -O2 -> -O3 -mcpu=apple-m4 -ffp-contract=fast -flto)         |
+---------------------------------------------------------------------------------------+
| regex scan NFA           0.0362s -> 0.0297s    (1.22x faster)  [####################] |
| regex replace NFA        0.0811s -> 0.0703s    (1.15x faster)  [###################.] |
| buffer sort              0.2609s -> 0.2497s    (1.04x faster)  [#################...] |
| vimscript loop 500k      0.4915s -> 0.4003s    (1.23x faster)  [####################] |
| regex on ruby code       0.0217s -> 0.0187s    (1.16x faster)  [###################.] |
|                                                                                       |
| CPU-bound speedup: ~15-23 %. Buffer sort is memory-bandwidth-bound (+4 % only).       |
+---------------------------------------------------------------------------------------+
```

This result is narrower than “Vim is 23% faster.” CPU-heavy regex and Vimscript loops improved by 15–23%; the memory-bound buffer sort improved by only 4%. Native compilation does not replace startup optimization, because compiler flags cannot eliminate plugins that should not have been loaded.

## Reproduce, upgrade, or restore

Run configuration validation before and after changing plugin loading:

```sh
./bootstrap/check_configs.sh
RUNS=7 ./benchmarks/profile_vim_plugins_median.sh
```

To install the native build, or rebuild it after a Homebrew upgrade:

```sh
./bootstrap/compile_vim_native.sh

brew unpin vim && brew upgrade vim \
  && ./bootstrap/compile_vim_native.sh
```

To return to the standard Homebrew bottle:

```sh
brew unpin vim && brew reinstall vim
```

The Homebrew receipt still describes the original formula installation after a binary-only replacement. Use `vim --version`, the script's verification output, and a fresh benchmark to identify and evaluate the native build.

## The order of operations

The practical priority is:

1. Measure repeated launches and report medians.
2. Delete duplicate or unused startup work.
3. Lazy-load expensive features at a clear command boundary.
4. Add guardrails for workloads such as large files.
5. Re-measure startup and normal editing behavior.
6. Only then test a native executable against the same-version bottle.

The first four steps improve the workload itself and travel with the dotfiles. The native binary is the final, machine-local layer—and the easiest one to restore when a benchmark does not justify it.

The implementation lives in [`.vimrc`](https://github.com/marianposaceanu/dot-files/blob/main/.vimrc), [`bootstrap/compile_vim_native.sh`](https://github.com/marianposaceanu/dot-files/blob/main/bootstrap/compile_vim_native.sh), and the [`benchmarks/`](https://github.com/marianposaceanu/dot-files/tree/main/benchmarks) directory.
