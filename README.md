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

#### vim shortcuts

- `<leader>a` (usually `\a`): run `:Rg` and type a ripgrep search query.
- `<leader>A` (usually `\A`): run `:Rg` for the word under cursor.
- `<leader>gs`: search git history for current line/selection and print commit URL.
- `<C-p>`: open `:Files` via `fzf.vim`.
- `<C-n>`: lazy-load and toggle NERDTree.
- `<leader>gv`: lazy-load and toggle GoldenView.
- `:Tabularize /<pattern>`: lazy-load Tabular and align by pattern (example: `:Tabularize /=>`).

#### cleanly remove a module

    git submodule deinit asubmodule
    git rm asubmodule

#### remove a broken module mapping

    git rm --cached <path_to_submodule>

#### add a new submodule

    git submodule add https://github.com/ayu-theme/ayu-vim.git .vim/pack/bundles/start/ayu-vim

### Symbolic links

#### *nix symbolic links

    ln -s ~/dot-files/.vimrc ~/.vimrc
    ln -s ~/dot-files/.vim ~
    ln -s ~/dot-files/.gitconfig ~/.gitconfig
    ln -s ~/dot-files/.gitignore_global ~/.gitignore_global
    ln -s ~/dot-files/.tmux.conf ~/.tmux.conf
    ln -s ~/dot-files/.zshrc ~/.zshrc
    ln -s ~/dot-files/bat ~/.config/bat
    ./bootstrap/backup_ghostty_config.sh
    ln -s ~/dot-files/ghostty/config "$HOME/Library/Application Support/com.mitchellh.ghostty/config"

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
