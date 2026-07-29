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

**Website:** [dotfiles overview](https://marianposaceanu.github.io/dot-files/) · [Ghostty + `rz` quick start](https://marianposaceanu.github.io/dot-files/ghostty.html)

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

    git clone git@github.com:marianposaceanu/dot-files.git

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
- current formulae: `fzf`, `ripgrep`, `bat`, `openjdk`, `universal-ctags`, `tmux`

#### bat

`cat` is aliased to `bat` in `.zshrc`. `bat` uses the TwoDark theme (complements ayu-dark) and shows line numbers and git change indicators. Man pages are also rendered through `bat` via `MANPAGER`. FZF file previews (`Ctrl-T`) use `bat` automatically. Inside FZF, use `Ctrl-J` / `Ctrl-K` to move one line, `Ctrl-D` / `Ctrl-U` to move half a page, and `Ctrl-/` to toggle the preview.

#### search

`ack` is aliased to `rg` in interactive Zsh and Bash sessions. Ripgrep is the
only search formula required; the Perl-based `ack` package is not installed.

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

| Workload | Native | Bottle | Native change |
| --- | ---: | ---: | ---: |
| Literal, one thread | 27.56 ms | 27.30 ms | +1.0% |
| Regex, one thread | 28.27 ms | 28.13 ms | +0.5% |
| Unicode regex, one thread | 91.40 ms | 93.28 ms | -2.0% |
| PCRE2 lookaround, one thread | 502.04 ms | 502.86 ms | -0.2% |
| Literal, default threads | 11.76 ms | 11.85 ms | -0.8% |
| 5,000-file traversal | 11.39 ms | 11.50 ms | -0.9% |

These results do not demonstrate a meaningful speed or power improvement. The
native workflow is retained for repeatable testing, not as a general claim that
rebuilding ripgrep is better than using its Homebrew bottle.

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
