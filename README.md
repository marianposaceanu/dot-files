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
|                   '---..____...---''                version: 1.0.12.2026              |
|                                                                                       |
+---------------------------------------------------------------------------------------+
```

# dot-files

Contains my dot-files for easy usage across different OSs.

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
non-empty scrollback. Restores always create new Ghostty windows, so existing tabs
are left alone. Window geometry capture requires macOS Accessibility permission
for the shell running `rz`.

```sh
rz --save work                 # save work_YYYYMMDD-HHMMSS
rz --save personal             # save a separate named snapshot
rz                             # restore the newest snapshot overall
rz --session work              # restore the newest snapshot named work
rz --session 20260719-230140   # restore a specific timestamp
rz --list                      # list snapshots
rz --session work --dry-run    # preview without changing Ghostty
```

Snapshots live in `~/.local/state/ghostty-rz/snapshots`. Reload the shell after
updating the dotfiles (`source ~/.zshrc` or `source ~/.bashrc`) before using `rz`.

Ghostty 1.3 exposes terminals as a flat collection per tab. It does not expose a
split tree, split directions, or pane proportions, and it has no JSON workspace
export/import API. `rz` therefore preserves the number of terminal surfaces but
recreates additional surfaces as right-hand splits. Scrollback is replayed as
plain text; arbitrary running programs cannot be reconstructed. Codex sessions
are resumed by their exact conversation ID.

### Submodules and bundles

#### update the bundles

    git submodule update --init --recursive

#### fully update all bundles

    git submodule update --remote --recursive

This updates plugin pointers in your repo; run it only when you intentionally want to bump submodule versions.

#### install deps:

- via script: `./bootstrap/install_brew_deps.sh`
- via Brewfile: `brew bundle --file Brewfile`
- current formulae: `fzf`, `ripgrep`, `bat`, `universal-ctags`, `tmux`

#### bat

`cat` is aliased to `bat` in `.zshrc`. `bat` uses the TwoDark theme (complements ayu-dark) and shows line numbers and git change indicators. Man pages are also rendered through `bat` via `MANPAGER`. FZF file previews (`Ctrl-T`) use `bat` automatically.

#### config and benchmark checks

- run environment doctor: `./bootstrap/doctor.sh`
- run config checks: `./bootstrap/check_configs.sh`
- single-run Vim profile: `./benchmarks/profile_vim_plugins.sh`
- median profile (default 7 runs): `./benchmarks/profile_vim_plugins_median.sh`

#### vim — native Apple Silicon build (optional)

Recompiles Vim using Homebrew's own formula with `-O3 -mcpu=native -flto` and pins
the formula so `brew upgrade` does not overwrite the custom binary.

```
./bootstrap/compile_vim_native.sh
```

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

#### *nix symbolic links

    ./bootstrap/link_configs.sh

The script creates symlinks for the repo-managed configs and backs up any existing local files/directories first using a `.backup.<timestamp>` suffix.

It links:

- `~/.vimrc`
- `~/.vim`
- `~/.gitconfig`
- `~/.gitignore_global`
- `~/.tmux.conf`
- `~/.zshrc`
- `~/.bashrc`
- `~/.screenrc`
- `~/.alacritty.yml`
- `~/.config/bat`
- `$HOME/Library/Application Support/com.mitchellh.ghostty/config`

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
