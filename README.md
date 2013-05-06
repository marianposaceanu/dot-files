# dot-files

Contains my dot-files for easy usage across different OSs.

#### theme preview

![Theme Preview](assets/preview.gif?raw=true)

#### contains

- VIM Config files and bundles
- VIM alternative icons in /assets/vim_icons

#### included bundles:

- _theme_
 - [Base16](https://github.com/chriskempson/base16-vim)
 - [Tomorrow](https://github.com/chriskempson/vim-tomorrow-theme)
 - [Wombat](https://github.com/cschlueter/vim-wombat)
- _syntax_
 - [CoffeeScript](https://github.com/kchmck/vim-coffee-script)
 - [Enhanced Javascript](https://github.com/jelera/vim-javascript-syntax)
 - [Markdown](https://github.com/tpope/vim-markdown)
- _specific_
 - [Commentary](https://github.com/tpope/vim-commentary)
 - [Ctrl+P](https://github.com/kien/ctrlp.vim)
 - [Fugitive](https://github.com/tpope/vim-fugitive)
 - [Supertab](https://github.com/ervandew/supertab)
 - [Surround](https://github.com/tpope/vim-surround)
 - [Tabular](https://github.com/godlygeek/tabular)
 - [The NERD Tree](https://github.com/scrooloose/nerdtree)
- _ruby_
 - [Bundler](https://github.com/tpope/vim-bundler) 
 - [Rails](https://github.com/tpope/vim-rails)
- _sublime-text related_
 - [Multiple Cursors](https://github.com/terryma/vim-multiple-cursors)

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
    
#### credits

- [inspired by Chris Hunt own dot files](https://github.com/chrishunt/dot-files#installation)
- [nice tip](http://pagesofinterest.net/blog/2013/05/switching-to-vim-1-start-at-the-beginning/)
- [mklink reference](http://technet.microsoft.com/en-us/library/cc753194%28v=ws.10%29.aspx)
