set nocompatible

" Pathogen
" ---------------------------------|
call pathogen#infect()
call pathogen#helptags()

syntax on

" OSX Faster performance
" ---------------------------------|
" notes tweak the key repeat and latency with https://pqrs.org/osx/karabiner/
set lazyredraw                    " more info: https://github.com/tpope/vim-sensible/issues/78
set ttyfast
set ttyscroll=3
set ttymouse=xterm2

" Theme
" ---------------------------------|
let base16colorspace=256
set background=dark

" Ruby is an oddball in the family, use special spacing/rules
if v:version >= 703
  " Note: Relative number is quite slow with Ruby, so is cursorline
  autocmd FileType ruby setlocal ts=2 sts=2 sw=2 norelativenumber nocursorline
else
  autocmd FileType ruby setlocal ts=2 sts=2 sw=2
endif

" Theme colors
" ---------------------------------|
colorscheme monokai                " requires https://github.com/crusoexia/vim-monokai
" colorscheme solarized
" colorscheme base16-railscasts      " requires https://github.com/chriskempson/base16-shell into .zshrc
" colorscheme molokai

filetype plugin indent on          " Enable file type detection and do language-dependent indenting.

set pastetoggle=<F2>               " easier pasting
set synmaxcol=200                  " fixes slow highlighting
set number
set hlsearch
set showmatch
set incsearch
set autoindent
set history=1000
set undolevels=1000
set cursorline
set expandtab
set autochdir
set backspace=indent,eol,start    " Intuitive backspacing.
set ignorecase                    " Case-insensitive searching.
set smartcase                     " But case-sensitive if expression contains a
                                  "  capital letter.
set incsearch                     " Highlight matches as you type.
set hlsearch                      " Highlight matches.
set scrolloff=3                   " Show 3 lines of context around the cursor.
set laststatus=2                  " Show the status line all the time
set encoding=utf-8                " Use UTF-8 everywhere.
set nowrap                        " Turn off line wrapping.
" set linebreak                     " ^
" set ttimeoutlen=50                " fix for slow after INSERT exit mode

set nobackup                      " Don't make a backup.
set nowritebackup                 " And again.
set noswapfile

set expandtab                     " Use spaces instead of tabs
set tabstop=2                     " Global tab width.
set shiftwidth=2                  " And again, related.
set softtabstop=2                 " This makes the backspace key treat the two
                                  "  spaces like a tab (so one backspace goes
                                  "  back a full 2 spaces).

if has('win32')                   " save swp files into tmp
  set dir=c:\\tmp
else
  set dir=~/tmp
endif


" FZF settings
" ---------------------------------|
let g:fzf_layout = { 'down': '40%' }
let $FZF_DEFAULT_COMMAND='git ls-files --exclude-standard -co'
set rtp+=/usr/local/opt/fzf
nnoremap <C-p> :Files<CR>

" Airline settings
" ---------------------------------|
" let g:airline_theme="base16"
let g:airline_theme="simple"

if !exists('g:airline_symbols')
  let g:airline_symbols = {}
endif
" unicode symbols
let g:airline_left_sep = '»'
let g:airline_left_sep = '▶'
let g:airline_right_sep = '«'
let g:airline_right_sep = '◀'
let g:airline_symbols.linenr = '␊'
let g:airline_symbols.linenr = '␤'
let g:airline_symbols.linenr = '¶'
let g:airline_symbols.branch = '⎇'
let g:airline_symbols.paste = 'ρ'
let g:airline_symbols.paste = 'Þ'
let g:airline_symbols.paste = '∥'
let g:airline_symbols.whitespace = 'Ξ'

" Toogle search highlighting
" ---------------------------------|
nnoremap <F3> :set hlsearch!<CR>

" Toggle spell check with <F5>
" ---------------------------------|
map <F5> :setlocal spell! spelllang=en_us<cr>
imap <F5> <ESC>:setlocal spell! spelllang=en_us<cr>

" Toogle alternate shortcut for BuffExplorer
"  explore/next/previous: Alt-F12, F12, Shift-F12.
" ---------------------------------|
nnoremap <silent> <M-F12> :BufExplorer<CR>
nnoremap <silent> <F12> :bn<CR>
nnoremap <silent> <S-F12> :bp<CR>

" Treat .ru Gemfile .pp files with as Ruby
au BufNewFile,BufRead Gemfile set filetype=ruby
au BufNewFile,BufRead *.ru set filetype ruby
au BufNewFile,BufRead *.pp set filetype ruby

" Map Ack
map <leader>a :Ack!<space>
" Search for word under cursor with ack
map <leader>A :Ack! "<C-r>=expand('<cword>')<CR>"

" Sorting words (not lines) in VIM
"  via http://stackoverflow.com/questions/1327978/sorting-words-not-lines-in-vim
vnoremap <F2> d:execute 'normal i' . join(sort(split(getreg('"'))), ' ')<CR>

" Check code complexity and duplication for current file
if has("gui_win32")
  map <leader>x :!cls &&
        \ echo '----- Complexity -----' && flog % &&
        \ echo '----- Duplication -----' && flay %<cr>
else
  map <leader>x :!clear &&
        \ echo '----- Complexity -----' && flog % &&
        \ echo '----- Duplication -----' && flay %<cr>
end

" Rename current file, via Gary Bernhardt
function! RenameFile()
  let old_name = expand('%')
  let new_name = input('New file name: ', expand('%'))
  if new_name != '' && new_name != old_name
    exec ':saveas ' . new_name
    exec ':silent !rm ' . old_name
    redraw!
  endif
endfunction
map <leader>n :call RenameFile()<cr>

" OSX Vim clipboard fixes
"  note: vim needs to be compiled with --enable-clipboard, --enable-xterm_clipboard
"  you can easily add them via: brew edit vim
" via:
"  https://coderwall.com/p/avmotq
"  http://stackoverflow.com/questions/13380643/vim-use-as-default-register-only-for-yank-command
nnoremap <expr> y (v:register ==# '"' ? '"+' : '') . 'y'
nnoremap <expr> yy (v:register ==# '"' ? '"+' : '') . 'yy'
nnoremap <expr> Y (v:register ==# '"' ? '"+' : '') . 'Y'
xnoremap <expr> y (v:register ==# '"' ? '"+' : '') . 'y'
xnoremap <expr> Y (v:register ==# '"' ? '"+' : '') . 'Y'

" yank text to OS X clipboard
" http://evertpot.com/osx-tmux-vim-copy-paste-clipboard/
set clipboard=unnamed

" no more .netrwhist file
let g:netrw_dirhistmax = 0

" quickfixopenall.vim
" Author:
"   Tim Dahlin
"
" Description:
"   Opens all the files in the quickfix list for editing.
"
" Usage:
"   1. Perform a vimgrep search
"       :vimgrep /def/ *.rb
"   2. Issue QuickFixOpenAll command
"       :QuickFixOpenAll
function!   QuickFixOpenAll()
    if empty(getqflist())
        return
    endif
    let s:prev_val = ""
    for d in getqflist()
        let s:curr_val = bufname(d.bufnr)
        if (s:curr_val != s:prev_val)
            exec "edit " . s:curr_val
        endif
        let s:prev_val = s:curr_val
    endfor
endfunction

command! QuickFixOpenAll call QuickFixOpenAll()

set clipboard=unnamed

" Bye bye arrow keys
" ---------------------------------|
map <up> <nop>
map <down> <nop>
map <left> <nop>
map <right> <nop>
imap <up> <nop>
imap <down> <nop>
imap <left> <nop>
imap <right> <nop>
