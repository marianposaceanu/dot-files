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
|                   '---..____...---''                                                  |
|                                                                                       |
+---------------------------------------------------------------------------------------+
```

# dot-files

My reproducible Apple Silicon macOS development environment: Ghostty, Zsh,
Vim, tmux, Git, Homebrew dependencies, and an idempotent bootstrapper.

**Website:** [dotfiles overview](https://dot.marianposaceanu.com/) ·
[Ghostty + `rz` quick start](https://dot.marianposaceanu.com/ghostty.html) ·
[zoxide directory jumping](https://dot.marianposaceanu.com/zoxide.html)

## Install on macOS

The installer checks Apple Command Line Tools, installs Homebrew when needed,
installs the dependencies in `Brewfile`, mextdisplay, and Ghostty, sets up Oh My
Zsh and Vim submodules, and links the configs. It is safe to rerun: valid links
and installations are retained, while conflicts are moved to timestamped
`.backup.<timestamp>` paths.

On a new Mac, the first `git` command may prompt for Apple Command Line Tools.
Finish that installation, then rerun the command.

The commands below require Homebrew to be installed and `brew` available in
your shell. If you already have a standalone Babashka (`bb`), the installer can
install Homebrew itself.

Clone the repository, install Babashka, and run the installer:

```sh
git clone https://github.com/marianposaceanu/dot-files.git ~/dot-files
cd ~/dot-files
brew install borkdude/brew/babashka
bb bootstrap/install_macos.clj
```

The installer presents a rounded bootstrap UI:

```text
╭─ DOT-FILES :: MACOS SETUP
│  Idempotent setup powered by Babashka
╰─ Existing files are backed up before links are changed

╭─ [01/10] Apple Command Line Tools
╰─
✓ Apple Command Line Tools are available.

╭─ SETUP COMPLETE
│  Your macOS dot-files environment is ready.
╰─ Next: restart the terminal or run source ~/.zshrc
```

The macOS installer keeps one global progress bar at the bottom of interactive
terminals. It advances as dependency checks, RVM milestones, plugin setup,
individual configuration links, and validation checks finish. Progress reflects
completed work rather than elapsed time; setup reaches 100% only after success.

Use `--timings` to report stage durations. Use `--skip-checks` only when you
will run the checks manually afterward. Licensed fonts,
credentials, keyboard preferences, and optional native builds remain manual.

`rvm/config.edn` lists required Ruby versions and the default. Setup installs RVM
stable when missing, installs required Rubies, and sets the default to Ruby
4.0.7. Existing Ruby versions and gemsets are retained. RVM's installer leaves
shell configs alone because the dotfiles already initialize it.

To check or install just the RVM requirements:

```sh
bb bootstrap/setup/install_rvm.clj --check
bb bootstrap/setup/install_rvm.clj
```

The doctor also reports missing Rubies and an incorrect default.

## Repository contents

- Vim configuration, local customizations, and pinned plugin submodules
- Zsh, Bash, tmux, Git, and global gitignore configuration
- Ghostty and bat configuration
- Amp, Codex, and Claude Code configuration in [`llm-harnesses/`](llm-harnesses/)
- Homebrew dependencies in `Brewfile`
- Bootstrap, linking, health-check, and benchmark tools
- Installer and editor regression tests under `test/`

## Homebrew dependencies

`Brewfile` is the source of truth. Install it directly or through the helper:

```sh
brew bundle --file Brewfile
bb bootstrap/setup/install_brew_deps.clj
```

## Custom tools

Tools maintained alongside these dotfiles:

| Tool | Purpose | Installation or command |
| --- | --- | --- |
| [mextdisplay](https://github.com/marianposaceanu/mextdisplay) | Enable and disable external displays on Apple Silicon Macs from a terminal UI or CLI. | `brew install marianposaceanu/tap/mextdisplay` |
| [rz](https://github.com/marianposaceanu/rz) | Save and restore Ghostty workspaces, including terminal history and supported coding sessions. | `brew install marianposaceanu/tap/rz` |
| [Safari Tab Weight](https://github.com/marianposaceanu/safari-tab-weight) | Inspect the current Safari tab’s observable resource weight, requests, and page structure. | [Build and enable in Safari](https://github.com/marianposaceanu/safari-tab-weight#run-in-safari) |
| [brew native](https://github.com/marianposaceanu/homebrew-tap#native-apple-silicon-builds) | Build Vim, Git, ripgrep, and Universal Ctags for the local Apple CPU. | `brew tap marianposaceanu/tap`, then `brew native` |

Homebrew packages are provided by [Marian’s tap](https://github.com/marianposaceanu/homebrew-tap).
The main `Brewfile` installs `mextdisplay` and `rz`. Native source builds are
optional; see [the native build instructions](#optional-native-apple-silicon-builds).

### Ghostty named workspaces (`rz`)

```sh
brew tap marianposaceanu/tap
brew install rz

rz --save work
rz --list
rz --session work
rz --watch backup --every 15m
rz --clean 30d
```

`rz` saves and restores named Ghostty workspaces. See the
[`rz` repository](https://github.com/marianposaceanu/rz) for behavior, options,
permissions, snapshot storage, and recovery details.

### mextdisplay

[mextdisplay](https://github.com/marianposaceanu/mextdisplay) is installed
through the main Brewfile. The `mext` alias opens its interface:

```sh
mext
mext list
mext disable EV3285
mext enable EV3285
```

## Shell tools

Oh My Zsh uses the `robbyrussell` theme and the `git` plugin. Autosuggestions
and syntax highlighting load separately from Homebrew; highlighting loads last.

- Zsh Autosuggestions offers history completions; press Right Arrow or `End` to
  accept one.
- `b` is aliased to `bat`; redirected output stays plain. Man pages and FZF
  previews also use `bat`.
- `z <keywords>` jumps with zoxide and `zi <keywords>` selects through FZF. See
  the [zoxide tutorial](https://dot.marianposaceanu.com/zoxide.html).
- `ack` is aliased to `rg` in interactive Zsh and Bash sessions.
- `Ctrl-R` searches shell history; `Ctrl-T` selects files with bat previews;
  `Alt-C` selects a directory.
- Inside fzf, `Ctrl-J`/`Ctrl-K` move through results, `Ctrl-D`/`Ctrl-U` move half
  a page, and `Ctrl-/` toggles the preview where one is configured.

The shell retains 50,000 history entries. File search includes hidden files,
excludes `.git`, and respects ignore files. `~/.ignore` adds exclusions for
local caches and database dumps; it affects ripgrep searches beneath your home
rather than acting as a Git ignore file.

## Optional native Apple Silicon builds

Native formulas and build implementations live in
[marianposaceanu/homebrew-tap](https://github.com/marianposaceanu/homebrew-tap).
The tap's `Formula/` directory contains Vim, Git, ripgrep, and Universal Ctags;
`native/` contains their build helpers. Dotfiles keeps small forwarding scripts
in `bootstrap/native/` so existing commands and benchmarks keep working.

```sh
brew tap marianposaceanu/tap
brew update                              # refresh upstream formula versions
brew native                               # regenerate, build, and pin all four
brew native vim ripgrep                   # a subset
brew native --formulas-only               # refresh portable Formula/*.rb
```

The existing dotfiles entry points delegate to the tap:

```sh
./bootstrap/native/brew_native.sh vim ripgrep
```

For a local tap checkout, select it explicitly:

```sh
NATIVE_TAP_ROOT=~/work/playground/homebrew-tap ./bootstrap/native/brew_native.sh --help
```

Committed formulas use `-O3 -mcpu=native`, plus Rust's native CPU flag and
`release-lto` profile for ripgrep. The build helper regenerates formulas from
current homebrew-core for the detected Apple CPU, installs through the fully
qualified tap name, and pins the resulting packages. `--formulas-only` defaults
to portable native flags; `NATIVE_CPU=apple-m1` selects an explicit CPU. These
operations modify the local tap's formula files. See the tap README for formula
maintenance and restoring stock bottles.

The older `compile_*_native.sh` implementations also live in the tap. Their
dotfiles forwarding commands still accept `--pgo`; they receive `DOT_FILES_REPO`
so training and verification use this repository's benchmarks. Results are
workload-dependent; see the
[step-by-step guide](https://dot.marianposaceanu.com/native-builds-guide.html) and
[Native Apple Silicon builds](https://dot.marianposaceanu.com/native-apple-silicon-builds.html).

The latest source installs were verified on an M1 Pro: Vim 9.2.1150, Git 2.56.0,
ripgrep 15.2.0, and Universal Ctags 6.2.1. All four formula tests and functional
checks passed. See the tap’s [installation record](https://github.com/marianposaceanu/homebrew-tap/blob/main/native/INSTALLATION.md)
for compiler evidence and commands to repeat the checks.

Native-build profiles:

```sh
./benchmarks/profile_vim_plugins.sh
./benchmarks/profile_vim_plugins_median.sh
./benchmarks/benchmark_ripgrep_native.sh "$(command -v rg)" native
./benchmarks/benchmark_ctags_native.sh
./benchmarks/benchmark_git_native.sh "$(command -v git)"
```

See [benchmarks/README.md](benchmarks/README.md) for dependencies, comparison
commands, power measurements, and how to interpret historical results.

## Validation

Run configuration checks and inspect the installed environment separately:

```sh
bb bootstrap/checks/check_configs.clj
bb bootstrap/checks/doctor.clj
```

The configuration checks validate shell and Babashka syntax, application configs,
installer idempotence, Vim behavior, and Ghostty configuration
when available. Editor regression tests cover Git errors and visual selections,
file search outside Git, large-file highlighting, recovery files, and plain bat
output when redirected. The doctor checks managed links and Homebrew dependencies.

Run the Babashka regression tests individually with:

```sh
bb test/editor_config_test.clj
bb test/install_macos_test.clj
```

For website edits, follow [the site instructions](bootstrap/site/instructions.md)
and use [the article template](bootstrap/site/tutorial_page.html). Published HTML
in `docs/` is the single source of truth; edit it directly, then review the
rendered pages, examples, links, and metadata. Site review happens during editing
and is separate from the configuration checker.

## Vim

Swap files, temporary write backups, and persistent undo live in private
subdirectories of `${XDG_STATE_HOME:-~/.local/state}/vim`. Successful writes
remove the temporary backup; undo history remains available after reopening.
Use `vim -r path/to/file` to recover a file from its swap file after a crash,
and `:earlier 5m` to move back through available undo history.
Files over 1 MB keep syntax and cursor-line highlighting disabled.

File search inherits the shell's fzf configuration, with a ripgrep fallback
that also works outside Git repositories. Git helpers resolve the repository
from the current file and report Git errors without constructing commit links.
Visual history searches use the selected lines, including their newlines.

### Shortcuts

- `<leader>a` (usually `\a`): run `:Rg` and enter a ripgrep query.
- `<leader>A` (usually `\A`): run `:Rg` for the word under the cursor.
- `<leader>gc`: browse per-file commit history with a diff preview (`:BCommits`).
- `<leader>gs`: search Git history for the line or selection and print its URL.
- `<leader>sw`: sort words in a visual selection.
- `<C-p>`: open `:Files` through `fzf.vim`.
- `<C-n>`: lazy-load and toggle NERDTree.
- `<leader>gv`: lazy-load and toggle GoldenView.
- `:Tabularize /<pattern>`: lazy-load Tabular and align by a pattern.
- `:Blame`: show blame information and the GitHub commit URL for the line.
- `:GBrowse`: open the current file, range, or commit on GitHub.
- `[c` / `]c`: jump to the previous or next Git hunk.
- `<leader>hp` / `<leader>hs` / `<leader>hu`: preview, stage, or undo a hunk.

### Submodules and bundles

Initialize or update pinned plugins:

```sh
bb bootstrap/submodules/update_submodules.clj
```

Intentionally update plugin pointers to upstream revisions:

```sh
bb bootstrap/submodules/update_submodules.clj --remote
```

Remove a submodule through the repository helper:

```sh
bb bootstrap/submodules/remove_submodule.clj <submodule-path>
```

## Symbolic links

Link all managed configuration with:

```sh
bb bootstrap/setup/link_configs.clj
```

This includes Ghostty and backs up conflicting files or directories with a
`.backup.<timestamp>` suffix. It links:

- `~/.vimrc`
- `~/.vim`
- `~/.gitconfig`
- `~/.gitignore_global`
- `~/.ignore`
- `~/.tmux.conf`
- `~/.zprofile`
- `~/.zshrc`
- `~/.zlogin`
- `~/.bashrc`
- `~/.codex/config.toml`
- `~/.claude/settings.json`
- `~/.claude/output-styles/amp.md`
- `~/.config/amp/settings.json`
- `~/.config/bat`
- `$HOME/Library/Application Support/com.mitchellh.ghostty/config`

Setup also merges `llm-harnesses/claude/config.json` into `~/.claude.json`, backing up an
existing file before changing it and preserving Claude's other preferences and
state. Codex and Claude copy mouse-selected text to the clipboard on release;
Ghostty's native selection also copies automatically.

## Zsh, tmux, and macOS notes

`.zprofile` initializes Homebrew in login shells. `.zshrc` configures the
interactive environment and loads RVM after its final PATH changes. `.zlogin`
provides guarded RVM initialization for non-interactive login shells.

Open a new terminal to apply shell changes and restart Vim to apply editor
changes. `bat` reads its configuration on each invocation.

Optionally make Zsh the default shell:

```sh
chsh -s "$(command -v zsh)"
```

tmux is installed through `Brewfile`; start it with `tmux`.

Set fast keyboard repeat:

```sh
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 12
```

Restore the macOS defaults:

```sh
defaults delete NSGlobalDomain KeyRepeat
defaults delete NSGlobalDomain InitialKeyRepeat
```

## Credits and learning

- [Chris Hunt's dotfiles](https://github.com/chrishunt/dot-files#installation)
- [Learning Vim](https://gist.github.com/marianposaceanu/5554601)
- [Vimcasts](http://vimcasts.org)
- [Vim packages](https://shapeshed.com/vim-packages/#how-it-works)
