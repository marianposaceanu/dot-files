# dot-files

Contains my dot-files for easy usage across different OSs.

#### theme preview

![Theme Preview](assets/preview.png?raw=true)

#### contains

- VIM Config files and bundles
- VIM alternative icons in /assets/vim_icons

#### usage

    git clone git://github.com/dakull/dot-files.git

#### update the bundles

    git submodule update --init

#### fully update all bundles

    git submodule foreach git pull origin master

#### cleanly remove a module

    git submodule deinit asubmodule
    git rm asubmodule

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

#### credits

- [inspired by Chris Hunt own dot files](https://github.com/chrishunt/dot-files#installation)
- [nice tip](http://pagesofinterest.net/blog/2013/05/switching-to-vim-1-start-at-the-beginning/)
- [mklink reference](http://technet.microsoft.com/en-us/library/cc753194%28v=ws.10%29.aspx)
- [learning vim](https://gist.github.com/dakull/5554601)
- [patched Consolas font](https://github.com/eugeneching/consolas-powerline-vim)
- [alternate patched Consolas font](https://github.com/nicolalamacchia/powerline-consolas)
- [patched Menlo, Inconsolata and Mensch fonts](https://gist.github.com/qrush/1595572)
- [all the Powerline font](https://github.com/Lokaltog/powerline-fonts)
- [Powerline font patcher](https://github.com/fatih/subvim/tree/master/vim/base/vim-powerline/fontpatcher)
- [precompiled ag for win platform](http://jaxbot.me/articles/ag_the_silver_searcher_for_windows_6_8_2013)

#### screencasts

- [the awesome vimcasts.org](http://vimcasts.org)
- [using Tabular](http://vimcasts.org/episodes/aligning-text-with-tabular-vim/)

#### Ack tips for Win platform

- [install Ack on win](http://stackoverflow.com/questions/1023710/how-can-i-install-and-use-ack-library-on-windows)
- [Perl for MS Windows](http://strawberryperl.com)
