```text
+---------------------------------------------------------------------------------------+
| MY DOT-FILES                                                                          |
+---------------------------------------------------------------------------------------+
|                                                                                       |
|                         .-=--.                                                        |
|                       .' .--. '.                                                      |
|                      :  : .-.'. :    _ _                                              |
|                      :  : : .': :   (o)o)                                             |
|                      :  '. '-' .'   ////                                              |
|                      _'.__'--=' '-.//'                                                |
|                   .-'               /                                                 |
|                   '---..____...---''                version: 1.1.07.2026              |
|                                                                                       |
+---------------------------------------------------------------------------------------+
```

# dot-files

Contains my dot-files for easy usage across different OSs.

**Website:** [dotfiles overview](https://dot.marianposaceanu.com/) · [Ghostty + `rz` quick start](https://dot.marianposaceanu.com/ghostty.html) · [zoxide directory jumping](https://dot.marianposaceanu.com/zoxide.html)

## Install on macOS

Clone the repository, then run the idempotent macOS installer:

```sh
git clone https://github.com/marianposaceanu/dot-files.git ~/dot-files
cd ~/dot-files
./bootstrap/install_macos.sh
```

On an untouched Mac, the first `git` command may ask to install Apple Command
Line Tools. Complete that installation and rerun the clone; the installer checks
the tools again before changing the machine.

The installer checks Apple Command Line Tools, installs Homebrew when missing,
installs the Brewfile formulae and Ghostty, clones Oh My Zsh without replacing
shell files, initializes the pinned Vim submodules, and invokes the existing
backup-aware config linker. Correct links and existing installations are left
alone on later runs. Conflicting config files are moved to timestamped
`.backup.<timestamp>` paths before linking.

Use `--skip-checks` only when the installation must finish before running the
repository validator and environment doctor manually.

Licensed fonts such as Berkeley Mono, RVM language runtimes, SSH credentials,
keyboard preferences, and the optional native CPU rebuilds remain manual. They
are machine- or user-specific and are not required for the guarded configs to
load successfully.

#### contains

- Vim config files and bundles
- Zsh / oh-my-zsh config
- tmux config
- Git config and global gitignore
- Ghostty terminal config
- Bootstrap scripts and environment doctor

#### set-up ssh keys

- https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent

#### usage

    git clone https://github.com/marianposaceanu/dot-files.git

### Ghostty named workspaces (`rz`)

`rz` saves and restores Ghostty windows, their macOS position and size, tabs,
terminal surfaces, focus, working directories, Codex conversation IDs, and
non-empty scrollback. A restore builds the new workspace first, then closes only
the Ghostty windows that existed when `rz` started. Use `--keep-existing` for an
additive restore that leaves those windows open. Window geometry and automatic
handling of Ghostty's close confirmation require macOS Accessibility permission
for the shell running `rz`.

```sh
rz --save work                 # save work_YYYYMMDD-HHMMSS
rz --save work --no-scrollback # fast snapshot without terminal history
rz --save work --current-window # save only the front Ghostty window
rz --save personal             # save a separate named snapshot
rz --watch backup --every 15m  # fast auto-save, bound to this window and shell
rz --watch-status              # inspect this shell's watcher
rz --watch-stop                # stop this shell's watcher
rz --clean                     # purge snapshots older than 7 days
rz --clean 30d                 # choose a different maximum age
rz --clean 2.weeks             # friendly long-form durations also work
rz                             # restore the newest snapshot overall
rz --session work              # restore the newest snapshot named work
rz --session 20260719-230140   # restore a specific timestamp
rz --keep-existing             # restore without closing existing windows
rz --list                      # list snapshots
rz --session work --dry-run    # preview without changing Ghostty
```

Replacement is ordered deliberately. `rz` records the existing Ghostty window
IDs, creates every restored window, and then invokes Ghostty's supported
`close_window` action only for the recorded IDs. If an old window still contains
a running process, `rz` confirms Ghostty's exact **Close Window?** sheet through
Accessibility. Restored terminals wait behind a short readiness gate until the
old windows have closed, so their Codex conversations do not get mistaken for
duplicates and downgraded to plain shells.

Snapshots live in `~/.local/state/ghostty-rz/snapshots`. Reload the shell after
updating the dotfiles (`source ~/.zshrc` or `source ~/.bashrc`) before using `rz`.
Use `--no-scrollback` when speed matters; window geometry, tabs, surfaces,
directories, focus, and Codex IDs are still saved. Scrollback exports are read
immediately when Ghostty's synchronous action returns, with one short compatibility
retry for asynchronous implementations; empty terminals no longer incur a
one-second timeout. The save confirmation lists every captured tab title, using
its window and tab position such as `TAB 1.3`.

Automatic watchers are opt-in and shell-scoped; there is no global daemon. A
watcher saves immediately and then at the requested interval, uses fast snapshots
without scrollback, and exits when the shell that started it disappears. Its
default scope is the Ghostty window that was frontmost at startup, and that window
ID stays bound even if focus later moves elsewhere. Use `--all-windows` only when
you explicitly want the broader scope:

```sh
rz --watch backup --every 15m               # current window, recommended
rz --watch backup --every 30m --all-windows # explicit full-app scope
```

Watcher state and logs live under `~/.local/state/ghostty-rz/watchers`. Periodic
snapshots accumulate normally; `rz` does not delete old snapshots automatically.
Run `rz --clean` to permanently remove snapshot directories whose recorded
`saved_at` time is more than seven days old, including their captured scrollback.
Pass another age when needed; cleanup accepts seconds, minutes, hours, days, or
weeks in forms such as `12h`, `7d`, `7.days`, and `2.weeks`. The result lists each
purged snapshot and keeps malformed or unsafe entries with a warning.

Ghostty 1.3 exposes terminals as a flat collection per tab. It does not expose a
split tree, split directions, or pane proportions, and it has no JSON workspace
export/import API. `rz` therefore preserves the number of terminal surfaces but
recreates additional surfaces as right-hand splits. Scrollback is replayed as
plain text; arbitrary running programs cannot be reconstructed. Codex sessions
are resumed by their exact conversation ID. Session matching is restricted to
Codex processes launched under Ghostty. It uses an exact working directory first,
then a unique project title or the same session ID's unique title from a previous
snapshot when Ghostty reports a blank directory. A successful fallback repairs
the saved directory, and restored terminals report that directory back to Ghostty
before Codex starts. Ambiguous sessions are never guessed; the warning identifies
the exact session ID and TTY for manual recovery.

### Submodules and bundles

#### update the bundles

    git submodule update --init --recursive

#### fully update all bundles

    git submodule update --remote --recursive

This updates plugin pointers in your repo; run it only when you intentionally want to bump submodule versions.

#### install deps:

- via script: `./bootstrap/install_brew_deps.sh`
- via Brewfile: `brew bundle --file Brewfile`
- current formulae: `fzf`, `zoxide`, `ripgrep`, `bat`, `ruby`, `openjdk`, `universal-ctags`, `tmux`, `vim`

#### bat

`cat` is aliased to `bat` in `.zshrc`. `bat` uses the TwoDark theme (complements ayu-dark) and shows line numbers and git change indicators. Man pages are also rendered through `bat` via `MANPAGER`. FZF file previews (`Ctrl-T`) use `bat` automatically. Inside FZF, use `Ctrl-J` / `Ctrl-K` to move one line, `Ctrl-D` / `Ctrl-U` to move half a page, and `Ctrl-/` to toggle the preview.

#### zoxide

Zoxide is initialized near the end of `.zshrc`, after completion setup and all
PATH changes. Use `z <keywords>` to jump to the highest-ranked matching
directory or `zi <keywords>` to choose interactively with FZF. Initialization
is guarded, so the shell still loads before the formula is installed. See the
[zoxide tutorial](https://dot.marianposaceanu.com/zoxide.html) for
installation, daily commands, ranking, and database maintenance.

#### search

`ack` is aliased to `rg` in interactive Zsh and Bash sessions. Ripgrep is the
only search formula required; the Perl-based `ack` package is not installed.

#### What LTO and PGO mean

**LTO (Link-Time Optimization)** lets the compiler optimize the complete
program while linking it, rather than optimizing each source file or library
in isolation. This can expose opportunities such as inlining functions across
file boundaries and removing code that is unused once the whole program is
visible. The native workflows use LTO together with `-O3` and
`-mcpu=native`. LTO generally increases build time and memory usage; it does
not add profiling overhead to the finished executable, and it does not
guarantee a measurable speedup for every workload.

**PGO (Profile-Guided Optimization)** is a two-stage build. First, the script
builds an instrumented executable and runs representative training workloads
to record which branches and functions are used most often. It then merges
those profiles and rebuilds the program so the compiler can optimize hot paths
and code layout using observed behavior. The final executable has no training
instrumentation. PGO is workload-specific: trained operations may improve
while unrelated operations remain unchanged or occasionally regress, which is
why these workflows benchmark the candidate before installing it.

The `--pgo` workflows combine both techniques: PGO supplies runtime behavior
to the compiler, while LTO gives it a whole-program view during the final
optimized build.

#### ripgrep — native Apple Silicon build (optional)

Recompiles the active Homebrew ripgrep version with its upstream `release-lto`
profile plus Rust's `-C target-cpu=native`. The script checksum-verifies the
formula's exact source, checks that Rust resolves the detected Apple generation
to the matching target (`apple-m1`, `apple-m4`, and so on), preserves PCRE2/JIT
and Homebrew dynamic linkage, runs literal, file-type, and PCRE2 smoke tests,
atomically replaces the binary with automatic rollback, then pins `ripgrep`.

```sh
./bootstrap/compile_ripgrep_native.sh
```

To upgrade and rebuild later:

```sh
brew unpin ripgrep && brew upgrade ripgrep \
  && ./bootstrap/compile_ripgrep_native.sh
```

Restore the standard Homebrew bottle with:

```sh
brew unpin ripgrep && brew reinstall ripgrep
```

The Homebrew receipt continues to describe the bottle after a custom build, so
use the script output and a benchmark rather than the receipt to identify the
native build.

The reproducible benchmark creates a deterministic 174 MiB corpus outside the
repository and reports medians after two warmups:

```sh
./benchmarks/benchmark_ripgrep_native.sh "$(command -v rg)" native
```

On the M1 Pro, 21 interleaved warm-cache repetitions of ripgrep 15.2.0 showed
that the native build was effectively neutral versus the official ARM64 Tahoe
bottle. Negative percentages are faster; differences around 1% are noise at
this duration.

```text
+---------------------------------------------------------------------------------------+
| RIPGREP NATIVE/LTO  (Homebrew ARM64 bottle -> native M1 Pro; lower is better)         |
+---------------------------------------------------------------------------------------+
| literal, one thread       27.30 ms ->  27.56 ms   (+1.0%, noise) [..................] |
| regex, one thread         28.13 ms ->  28.27 ms   (+0.5%, noise) [..................] |
| Unicode regex             93.28 ms ->  91.40 ms   (-2.0% faster) [####..............] |
| PCRE2 lookaround         502.86 ms -> 502.04 ms   (-0.2%, noise) [..................] |
| literal, default threads  11.85 ms ->  11.76 ms   (-0.8%, noise) [..................] |
| 5,000-file traversal      11.50 ms ->  11.39 ms   (-0.9%, noise) [..................] |
|                                                                                       |
| Result: effectively neutral; no general speed or power improvement demonstrated.      |
+---------------------------------------------------------------------------------------+
```

These results do not demonstrate a meaningful speed or power improvement. The
native workflow is retained for repeatable testing, not as a general claim that
rebuilding ripgrep is better than using its Homebrew bottle.

For an experimental profile-guided build, add `--pgo`:

```sh
./bootstrap/compile_ripgrep_native.sh --pgo
```

This requires Homebrew LLVM with the exact LLVM version used by Homebrew Rust;
the script refuses a mismatch. It builds an instrumented binary, trains it on
literal, regex, Unicode, PCRE2, traversal, and 1/2/4/8/default-thread searches,
merges the profiles, then performs a clean `release-lto` build with
`profile-use`. Training data and instrumented binaries remain temporary.

On the same M1 Pro and corpus, 21 interleaved repetitions compared the PGO
build with the official bottle:

```text
+---------------------------------------------------------------------------------------+
| RIPGREP PGO  (Homebrew ARM64 bottle -> native M1 Pro + LTO + PGO; lower is better)    |
+---------------------------------------------------------------------------------------+
| literal, one thread       27.52 ms ->  27.20 ms   (-1.1% faster) [##................] |
| regex, one thread         28.35 ms ->  27.96 ms   (-1.4% faster) [##................] |
| Unicode regex             93.67 ms ->  83.79 ms  (-10.5% faster) [##################] |
| PCRE2 lookaround         503.33 ms -> 496.26 ms   (-1.4% faster) [##................] |
| literal, two threads      18.91 ms ->  18.69 ms   (-1.2% faster) [##................] |
| literal, four threads     14.75 ms ->  14.37 ms   (-2.5% faster) [####..............] |
| literal, eight threads    12.08 ms ->  11.79 ms   (-2.3% faster) [####..............] |
| literal, default threads  11.90 ms ->  11.71 ms   (-1.6% faster) [###...............] |
| 5,000-file traversal      11.56 ms ->  12.02 ms   (+3.9% slower) [#######...........] |
|                                                                                       |
| Result: PGO materially helps Unicode regex; other changes are small or workload-bound.|
+---------------------------------------------------------------------------------------+
```

PGO materially improved the trained Unicode-regex workload. Most other gains
were only 1–3%, and traversal was slower in this run, so PGO remains
workload-specific rather than a universal improvement.

Threading had a larger effect on the literal workload than PGO. Relative to
the PGO build's one-thread median, two threads were 1.46x faster, four were
1.89x, eight were 2.31x, and automatic threading was 2.32x. Leave ripgrep's
thread count at its automatic default unless a representative benchmark shows
that a fixed count is better.

#### Universal Ctags — native Apple Silicon build (optional)

The Ctags workflow rebuilds only the active Homebrew keg's `ctags` executable
with Homebrew LLVM, `-O3 -mcpu=native`, and LTO. It validates the exact formula
source and SHA-256, detects Apple generations dynamically (including M4), and
requires the candidate's optional features and dynamic libraries to exactly
match the installed baseline. Parser smoke tests and an interleaved benchmark
run before an atomic replacement; failures restore the original binary and pin
state. No `make install` is run.

```sh
brew install docutils llvm
./bootstrap/compile_ctags_native.sh --pgo
```

Omit `--pgo` for the plain native/LTO build. To update or restore the bottle:

```sh
brew unpin universal-ctags && brew upgrade universal-ctags \
  && ./bootstrap/compile_ctags_native.sh --pgo
brew unpin universal-ctags && brew reinstall universal-ctags
```

On the M1 Pro, five interleaved repetitions of Universal Ctags 6.2.1 produced
the following medians. The first chart compares native/LTO with the bottle;
the second compares PGO with the already-installed native/LTO build. Negative
percentages are faster.

```text
+---------------------------------------------------------------------------------------+
| CTAGS NATIVE/LTO  (Homebrew ARM64 bottle -> native M1 Pro; lower is better)           |
+---------------------------------------------------------------------------------------+
| C parser                   80.19 ms -> 71.68 ms  (-10.6% faster) [##################] |
| Ruby parser                46.58 ms -> 41.91 ms  (-10.0% faster) [#################.] |
| JSON and YAML parsers      67.22 ms -> 63.34 ms   (-5.8% faster) [##########........] |
| representative mixed       27.13 ms -> 27.01 ms   (-0.5%, noise) [..................] |
|                                                                                       |
| Result: meaningful gains on language-specific parser workloads.                       |
+---------------------------------------------------------------------------------------+

+---------------------------------------------------------------------------------------+
| CTAGS PGO  (native M1 Pro + LTO -> native M1 Pro + LTO + PGO; lower is better)        |
+---------------------------------------------------------------------------------------+
| C parser                   72.30 ms -> 63.28 ms  (-12.5% faster) [##################] |
| Ruby parser                41.33 ms -> 37.73 ms   (-8.7% faster) [#############.....] |
| JSON and YAML parsers      63.09 ms -> 60.06 ms   (-4.8% faster) [#######...........] |
| representative mixed       26.69 ms -> 26.72 ms   (+0.1%, noise) [..................] |
|                                                                                       |
| Result: PGO adds parser-specific gains but is neutral on the small mixed corpus.      |
+---------------------------------------------------------------------------------------+
```

PGO helped the trained language-specific workloads but was neutral on the
small mixed corpus. Only the `ctags` executable is optimized; the rest of the
Homebrew keg remains the standard bottle installation.

#### Git — native Apple Silicon build (optional)

The Git workflow rebuilds only Homebrew Git 2.55.0's main `git` executable and
therefore its builtins. External helpers and support files remain bottle-built.
It uses Homebrew LLVM with `-O3 -mcpu=native -flto`, preserves Homebrew's
CommonCrypto, PCRE2, gettext, system libcurl/libiconv, runtime-prefix, and
documentation paths, then checks temporary-repository operations before an
atomic binary replacement. The script intentionally fails closed when the
installed Git version or formula contract changes.

```sh
brew install llvm pkgconf
./bootstrap/compile_git_native.sh --pgo
```

Omit `--pgo` for native/LTO without profile guidance. To update or restore:

```sh
brew unpin git && brew upgrade git && ./bootstrap/compile_git_native.sh --pgo
brew unpin git && brew reinstall git
```

The deterministic benchmark creates 30 revisions in a temporary repository,
checks output equivalence, alternates comparison order, and measures combined
CPU time for status, diff, grep/PCRE2, log, object traversal, fsck, and
commit-graph verification. On the M1 Pro, five repetitions measured **0.070 CPU
seconds** for native/LTO and **0.070 seconds** for the bottle. PGO was likewise
**0.070 seconds** against native/LTO. This is effectively neutral; the workflow
is retained for reproducible experimentation, not as evidence that rebuilding
Git is faster or saves power.

```text
+---------------------------------------------------------------------------------------+
| GIT NATIVE BUILD  (aggregate benchmark CPU time; lower is better)                     |
+---------------------------------------------------------------------------------------+
| Homebrew ARM64 bottle -> native M1 Pro + LTO     0.070s -> 0.070s  [................] |
| native M1 Pro + LTO -> native M1 Pro + LTO + PGO 0.070s -> 0.070s  [................] |
|                                                                                       |
| Result: no measurable change for this workload; external helpers remain bottle-built. |
+---------------------------------------------------------------------------------------+
```

#### config and benchmark checks

- run environment doctor: `./bootstrap/doctor.sh`
- run config checks: `./bootstrap/check_configs.sh`
- single-run Vim profile: `./benchmarks/profile_vim_plugins.sh`
- median profile (default 7 runs): `./benchmarks/profile_vim_plugins_median.sh`

#### vim — native Apple Silicon build (optional)

Recompiles the active Homebrew Vim version from its checksum-verified source
with `-O3 -mcpu=native -ffp-contract=fast -flto`, preserves the installed
formula's features and dynamic interpreter paths, and pins the formula so
`brew upgrade` does not overwrite the custom binary.

```
./bootstrap/compile_vim_native.sh
```

The script validates the source against the active keg's formula snapshot,
builds in a controlled environment, exercises Perl, Ruby, Python, and Lua,
checks Homebrew library linkage and runtime paths, and only then atomically
replaces the Cellar binary. A failed install restores the previous binary and
the original pin state. Homebrew's receipt still describes the original
bottle; use `brew reinstall vim` to restore a standard Homebrew build.

To upgrade Vim later:

```
brew unpin vim && brew upgrade vim && ./bootstrap/compile_vim_native.sh
```

#### vim startup improvement map

```
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

#### vim native build benchmark

```
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

#### vim shortcuts

- `<leader>a` (usually `\a`): run `:Rg` and type a ripgrep search query.
- `<leader>A` (usually `\A`): run `:Rg` for the word under cursor.
- `<leader>gc`: browse per-file commit history with diff preview (`:BCommits`).
- `<leader>gs`: search git log for the line/selection under cursor and print commit URL.
- `<leader>sw`: sort words in a visual selection (alphabetically).
- `<C-p>`: open `:Files` via `fzf.vim`.
- `<C-n>`: lazy-load and toggle NERDTree.
- `<leader>gv`: lazy-load and toggle GoldenView.
- `:Tabularize /<pattern>`: lazy-load Tabular and align by pattern (example: `:Tabularize /=>`).
- `:Blame`: show blame info and GitHub commit URL for the current line.
- `:GBrowse`: open current file, line range (visual), or commit on GitHub (vim-rhubarb).
- `[c` / `]c`: jump to previous/next git hunk (vim-gitgutter).
- `<leader>hp` / `<leader>hs` / `<leader>hu`: preview / stage / undo hunk (vim-gitgutter).

#### cleanly remove a module

    git submodule deinit asubmodule
    git rm asubmodule

#### remove a broken module mapping

    git rm --cached <path_to_submodule>

#### add a new submodule

    git submodule add https://github.com/ayu-theme/ayu-vim.git .vim/pack/bundles/start/ayu-vim

### Symbolic links

#### Ghostty config

    ./bootstrap/link_ghostty_config.sh

The dedicated Ghostty installer replaces
`$HOME/Library/Application Support/com.mitchellh.ghostty/config` with a symlink
to `ghostty/config` in this repository. If the destination is a regular file,
directory, broken symlink, or a symlink to another target, the script first moves
it to a timestamped `config.backup.<timestamp>` path. Running the script again
when the correct link is already installed is safe and makes no changes.

#### *nix symbolic links

    ./bootstrap/link_configs.sh

The all-config installer includes Ghostty and creates symlinks for every
repo-managed config. It backs up existing local files/directories first using a
`.backup.<timestamp>` suffix.

It links:

- `~/.vimrc`
- `~/.vim`
- `~/.gitconfig`
- `~/.gitignore_global`
- `~/.tmux.conf`
- `~/.zprofile`
- `~/.zshrc`
- `~/.zlogin`
- `~/.bashrc`
- `~/.screenrc`
- `~/.alacritty.yml`
- `~/.config/bat`
- `$HOME/Library/Application Support/com.mitchellh.ghostty/config`

For Zsh, `.zprofile` initializes Homebrew in login shells, `.zshrc` configures
the interactive environment and loads RVM after its final PATH changes, and
`.zlogin` supplies the guarded RVM initialization needed by non-interactive
login shells.

#### macOS keyboard key repeat

```
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 12
```

reset back to defaults:

```
defaults delete NSGlobalDomain KeyRepeat
defaults delete NSGlobalDomain InitialKeyRepeat
```

#### zsh

- install oh-my-zsh from: [oh-my-zsh](https://github.com/ohmyzsh/ohmyzsh)

optional: set zsh as the default shell

```
chsh -s $(which zsh)
```

#### tmux

```
brew install tmux
```

#### ssh keys

cp them into `~/.ssh` and add proper permissions:

```
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
chmod 644 ~/.ssh/authorized_keys
sudo launchctl stop com.openssh.sshd && sudo launchctl start com.openssh.sshd
```

#### credits

- [inspired by Chris Hunt own dot files](https://github.com/chrishunt/dot-files#installation)
- [nice tip](http://pagesofinterest.net/blog/2013/05/switching-to-vim-1-start-at-the-beginning/)
- [learning vim](https://gist.github.com/marianposaceanu/5554601)
- [patched Consolas font](https://github.com/eugeneching/consolas-powerline-vim)
- [alternate patched Consolas font](https://github.com/nicolalamacchia/powerline-consolas)
- [patched Menlo, Inconsolata and Mensch fonts](https://gist.github.com/qrush/1595572)
- [all the Powerline font](https://github.com/Lokaltog/powerline-fonts)
- [Powerline font patcher](https://github.com/fatih/subvim/tree/master/vim/base/vim-powerline/fontpatcher)
- [vim-airline-themes](https://github.com/vim-airline/vim-airline-themes)
- [vim-colors-solarize](https://github.com/altercation/vim-colors-solarize)
- [custom font size](http://apple.stackexchange.com/questions/198518/how-to-make-font-size-equal-to-15-in-terminal-on-yosemite)
- [key repeat](https://coderwall.com/p/jzuuzg/osx-set-fast-keyboard-repeat-rate)
- [vim-packages](https://shapeshed.com/vim-packages/#how-it-works)
- [Fully remove Git Submodule](https://gist.github.com/raulferras/8420865)

#### screencasts

- [the awesome vimcasts.org](http://vimcasts.org)
- [using Tabular](http://vimcasts.org/episodes/aligning-text-with-tabular-vim/)

#### tips - fully remove a submodule

    ./bootstrap/remove_submodule.sh <submodule-path>
