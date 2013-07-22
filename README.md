# dot-files

Contains my dot-files for easy usage across different OSs.

#### theme preview

![Theme Preview](assets/preview.png?raw=true)

#### contains

- VIM Config files and bundles
- VIM alternative icons in /assets/vim_icons

#### usage

    $ git clone git://github.com/dakull/dot-files.git

#### update the bundles

    $ git submodule init
    $ git submodule update

#### windows symbolic links

##### for config files

    > mklink /h "\Program Files (x86)\Vim\_gvimrc" "\[path-to-dot-files]\dot-files\.vim\_gvimrc"
    > mklink /h "\Program Files (x86)\Vim\_vimrc" "\[path-to-dot-files]\dot-files\.vim\_vimrc"

##### for bundle folder

    > mklink /j "\Program Files (x86)\Vim\vim73\bundle" "\[path-to-dot-files]\dot-files\.vim\bundle"

#### *nix symbolic links

    $ ln -s .vim/_vimrc .vimrc
    $ ln -s .vim/_gvimrc .gvimrc

#### included bundles:

theme | syntax | specific | ruby | sublime-text
--- | --- | --- | --- | ---
[Base16](https://github.com/chriskempson/base16-vim) | --- | --- | --- | ---
[Tomorrow](https://github.com/chriskempson/vim-tomorrow-theme) | --- | --- | --- | ---
[Wombat](https://github.com/cschlueter/vim-wombat) | --- | --- | --- | ---
--- | [CoffeeScript](https://github.com/kchmck/vim-coffee-script) | --- | --- | --- | ---
--- | [Enhanced Javascript](https://github.com/jelera/vim-javascript-syntax) | --- | --- | --- | ---
--- | [Markdown](https://github.com/tpope/vim-markdown) | --- | --- | --- | ---
--- | --- | [Commentary](https://github.com/tpope/vim-commentary) | --- | ---
--- | --- | [Ctrl+P](https://github.com/kien/ctrlp.vim) | --- | ---
--- | --- | [Fugitive](https://github.com/tpope/vim-fugitive) | --- | ---
--- | --- | [Supertab](https://github.com/ervandew/supertab) | --- | ---
--- | --- | [Surround](https://github.com/tpope/vim-surround) | --- | ---
--- | --- | [Tabular](https://github.com/godlygeek/tabular) | --- | ---
--- | --- | [The NERD Tree](https://github.com/scrooloose/nerdtree) | --- | ---
--- | --- | [Powerline](https://github.com/Lokaltog/vim-powerline) | --- | ---
--- | --- | [Airline](https://github.com/bling/vim-airline) | --- | ---
--- | --- | [Golden Ratio](https://github.com/roman/golden-ratio) | --- | ---
--- | --- | [ag](https://github.com/rking/ag.vim) | --- | ---
--- | --- |  --- | [Bundler](https://github.com/tpope/vim-bundler) | ---
--- | --- |  --- | [Rails](https://github.com/tpope/vim-rails) | ---
--- | --- |  --- |  --- | [Multiple Cursors](https://github.com/terryma/vim-multiple-cursors)

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
