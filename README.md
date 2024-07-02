# dot-files

Contains my dot-files for easy usage across different OSs.

#### theme preview

![Theme Preview](assets/preview_24.jpg?raw=true)

#### contains

- VIM Config files and bundles
- VIM alternative icons in /assets/vim_icons

#### set-up ssh keys

- https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent

#### usage

    git clone git@github.com:marianposaceanu/dot-files.git

### Submodules and bundles

#### update the bundles

    git submodule update --init

#### fully update all bundles

    git submodule foreach git pull origin master

#### install deps:

- FZF: `brew update; brew reinstall fzf`
- FZF+: `brew install fzf bat ripgrep the_silver_searcher perl universal-ctags`

#### cleanly remove a module

    git submodule deinit asubmodule
    git rm asubmodule

#### remove a broken module mapping

    git rm --cached <path_to_submodule>

#### add a new submodule

    git submodule add https://github.com/ayu-theme/ayu-vim.git .vim/pack/bundles/start/ayu-vim

### Symbolic links

#### windows symbolic links

    mklink /h "c:\Program Files (x86)\Vim\.gvimrc" "\dot-files\.vim\.gvimrc"
    mklink /h "c:\Program Files (x86)\Vim\.vimrc" "\dot-files\.vim\.vimrc"
    mklink /j "\Program Files (x86)\Vim\vim74\bundle" "\[path-to-dot-files]\dot-files\.vim\bundle"
    mklink /h "c:\Users\conta_000\.gitconfig" .gitconfig

#### *nix symbolic links

    ln -s ~/dot-files/.vimrc ~/.vimrc
    ln -s ~/dot-files/.gvimrc ~/.gvimrc
    ln -s ~/dot-files/.vim ~
    ln -s ~/dot-files/.gitconfig ~/.gitconfig
    ln -s ~/dot-files/.tmux.conf ~/.tmux.conf
    ln -s ~/dot-files/.zshrc ~/.zshrc

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

- install oh-my-zsh from: [oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh)

#### iTerm config

- set the default scheme to base16: load it from iterm-colorschemes
- set the b/g color from pure black to `#333333` and foreground to `#ebe6e2`

optional: set zsh as the default shell

```
chsh -s `which zsh`
```

#### tmux

```
brew install tmux
brew install reattach-to-user-namespace
```

via [fix-vim-tmux-yank-paste-on-unnamed-register](https://stackoverflow.com/questions/11404800/fix-vim-tmux-yank-paste-on-unnamed-register)

#### ssh keys

cp them into `~/.ssh` and add proper permissions:

```
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
chmod 644 ~/.ssh/authorized_keys
service ssh restart
```

#### credits

- [inspired by Chris Hunt own dot files](https://github.com/chrishunt/dot-files#installation)
- [nice tip](http://pagesofinterest.net/blog/2013/05/switching-to-vim-1-start-at-the-beginning/)
- [mklink reference](http://technet.microsoft.com/en-us/library/cc753194%28v=ws.10%29.aspx)
- [learning vim](https://gist.github.com/marianposaceanu/5554601)
- [patched Consolas font](https://github.com/eugeneching/consolas-powerline-vim)
- [alternate patched Consolas font](https://github.com/nicolalamacchia/powerline-consolas)
- [patched Menlo, Inconsolata and Mensch fonts](https://gist.github.com/qrush/1595572)
- [all the Powerline font](https://github.com/Lokaltog/powerline-fonts)
- [Powerline font patcher](https://github.com/fatih/subvim/tree/master/vim/base/vim-powerline/fontpatcher)
- [precompiled ag for win platform](http://jaxbot.me/articles/ag_the_silver_searcher_for_windows_6_8_2013)
- [vim-airline-themes](https://github.com/vim-airline/vim-airline-themes)
- [vim-colors-solarize](https://github.com/altercation/vim-colors-solarize)
- [custom font size](http://apple.stackexchange.com/questions/198518/how-to-make-font-size-equal-to-15-in-terminal-on-yosemite)
- [key repeat](https://coderwall.com/p/jzuuzg/osx-set-fast-keyboard-repeat-rate)
- [vim-packages](https://shapeshed.com/vim-packages/#how-it-works)
- [Fully remove Git Submodule](https://gist.github.com/raulferras/8420865)

#### screencasts

- [the awesome vimcasts.org](http://vimcasts.org)
- [using Tabular](http://vimcasts.org/episodes/aligning-text-with-tabular-vim/)

#### Ack tips for Win platform

- [install Ack on win](http://stackoverflow.com/questions/1023710/how-can-i-install-and-use-ack-library-on-windows)
- [Perl for MS Windows](http://strawberryperl.com)

#### tips - fully remove a submodule

    git submodule deinit -f .vim/bundle/modul-name
    git rm -f .vim/bundle/modul-name
