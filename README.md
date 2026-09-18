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

╭─ [01/09] Apple Command Line Tools
╰─
✓ Apple Command Line Tools are available.

╭─ SETUP COMPLETE
│  Your macOS dot-files environment is ready.
╰─ Next: restart the terminal or run source ~/.zshrc
```

Use `--timings` to report stage durations. Use `--skip-checks` only when you
will run the checks manually afterward. Licensed fonts, RVM language runtimes,
credentials, keyboard preferences, and optional native builds remain manual.

## Repository contents

- Vim configuration, local customizations, and pinned plugin submodules
- Zsh, Bash, tmux, Git, and global gitignore configuration
- Ghostty, bat, Amp, Codex, and Claude Code configuration
- Homebrew dependencies in `Brewfile`
- Bootstrap, linking, health-check, and benchmark tools

## Homebrew dependencies

`Brewfile` is the source of truth. Install it directly or through the helper:

```sh
brew bundle --file Brewfile
bb bootstrap/setup/install_brew_deps.clj
```

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

### Shell tools

- Zsh Autosuggestions offers history completions; press Right Arrow or `End` to
  accept one.
- `cat` is aliased to `bat`; man pages and FZF previews also use `bat`.
- `z <keywords>` jumps with zoxide and `zi <keywords>` selects through FZF. See
  the [zoxide tutorial](https://dot.marianposaceanu.com/zoxide.html).
- `ack` is aliased to `rg` in interactive Zsh and Bash sessions.

## Optional native Apple Silicon builds

Vim, Git, ripgrep and Universal Ctags are built by Homebrew itself from a local
tap (`marian/local`) with `-O3 -mcpu=<local Apple CPU>` (plus
`RUSTFLAGS=-C target-cpu=...` and the `release-lto` profile for ripgrep).
The generated formulas are versioned in `bootstrap/native/formulas/` and the
tools are pinned so `brew upgrade` leaves them alone. Results are
workload-dependent; see
[Native Apple Silicon builds](https://dot.marianposaceanu.com/native-apple-silicon-builds.html)
for design, benchmarks, and caveats.

One command does everything (regenerate formulas, build, pin):

```sh
./bootstrap/native/brew_native.sh                  # all four
./bootstrap/native/brew_native.sh vim ripgrep      # subset
./bootstrap/native/brew_native.sh --formulas-only  # only refresh formulas/*.rb
```

Why a tap: Homebrew's superenv compiler shim strips any `-O`/`-mcpu` flag and
injects nothing for Apple CPUs, so plain `brew reinstall --build-from-source`
yields a generic arm64 binary, and `--env=std` is no longer accepted on the
command line. A formula can still opt into stdenv with `env :std`, where the
real clang honours CFLAGS. The script copies the current homebrew-core formula,
removes its bottle block, adds `env :std` and the flags, and lets brew build it.

### Manual steps (what the script does)

1. Resolve the CPU name: `clang -mcpu=native -### -x c /dev/null 2>&1 | grep target-cpu`
   (e.g. `apple-m4`).
2. Create the tap once: `brew tap-new --no-git marian/local`.
3. Copy the core formula: `cp "$(brew formula homebrew/core/vim)" "$(brew --repo marian/local)/Formula/vim.rb"`.
4. Edit it: delete the `bottle do ... end` block, add `env :std` above
   `def install`, and as the first line of `install` add
   `ENV.append_to_cflags "-O3 -mcpu=apple-m4"`. For vim also replace
   `--with-compiledby=Homebrew` with `--with-compiledby=native-apple-m4` and add
   `--with-modified-by=[ apple-m4 :: -O3 -mcpu=apple-m4 ]` so `:version` shows
   the flags. For ripgrep set `ENV["RUSTFLAGS"] = "-C target-cpu=apple-m4"` and
   pass `"--profile", "release-lto"` to `cargo install`.
5. Save a copy to `bootstrap/native/formulas/<name>.rb` and commit it.
6. Install: `brew uninstall --ignore-dependencies vim` then
   `brew install --build-from-source marian/local/vim`. Uninstall first:
   `brew reinstall marian/local/vim` on a keg that came from core silently
   reuses the core formula.
7. Pin: `brew pin vim`.

To pick up a new upstream version, run the script again (it re-copies the
current core formula). Restore stock Homebrew bottles with:

```sh
for f in vim ripgrep universal-ctags git; do
  brew unpin "$f" && brew uninstall --ignore-dependencies "$f" && brew install "homebrew/core/$f"
done
```

The older `bootstrap/native/compile_*_native.sh` scripts (which build outside
brew and swap the binary into the keg, optionally with `--pgo`) are kept for
reference and benchmarking but are superseded by the tap approach.

Checks and profiles:

```sh
bb bootstrap/checks/check_configs.clj
bb bootstrap/checks/doctor.clj
./benchmarks/profile_vim_plugins.sh
./benchmarks/profile_vim_plugins_median.sh
./benchmarks/benchmark_ripgrep_native.sh "$(command -v rg)" native
./benchmarks/benchmark_ctags_native.sh
./benchmarks/benchmark_git_native.sh
```

## Vim

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

## Zsh, tmux, and macOS notes

`.zprofile` initializes Homebrew in login shells. `.zshrc` configures the
interactive environment and loads RVM after its final PATH changes. `.zlogin`
provides guarded RVM initialization for non-interactive login shells.

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
