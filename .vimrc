set nocompatible

" Pathogen
call pathogen#infect()
call pathogen#helptags()

filetype plugin indent on

syntax on

set background=dark
colorscheme base16-railscasts      " preview http://chriskempson.github.io/base16

" set synmaxcol=90                 " fixes slow highlighting
set number
set hlsearch
set showmatch
set incsearch
set autoindent
set history=1000
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

set expandtab                     " Use spaces instead of tabs
set tabstop=2                     " Global tab width.
set shiftwidth=2                  " And again, related.
set softtabstop=2                 " This makes the backspace key treat the two
                                  "  spaces like a tab (so one backspace goes
                                  "  back a full 2 spaces).
                                  
" set fileformats=unix              " just use the unix ff eveywhere

if has('win32')                   " save swp files into tmp
  set dir=c:\\tmp
else
  set dir=~/tmp
endif

" Airline settings
"  let g:airline_powerline_fonts=1
let g:airline_theme="simple"
let g:airline_left_sep = '»'
let g:airline_right_sep = '«'
let g:airline_linecolumn_prefix = '¶ '
let g:airline_paste_symbol = 'ρ'
let g:airline_paste_symbol = 'Þ'

" Toogle search highlighting
nnoremap <F3> :set hlsearch!<CR>

" Toggle spell check with <F5>
map <F5> :setlocal spell! spelllang=en_us<cr>
imap <F5> <ESC>:setlocal spell! spelllang=en_us<cr>

" Toogle alternate shortcut for BuffExplorer
"  explore/next/previous: Alt-F12, F12, Shift-F12.
nnoremap <silent> <M-F12> :BufExplorer<CR>
nnoremap <silent> <F12> :bn<CR>
nnoremap <silent> <S-F12> :bp<CR>

" Bye bye arrow keys
map <up> <nop>
map <down> <nop>
map <left> <nop>
map <right> <nop>
imap <up> <nop>
imap <down> <nop>
imap <left> <nop>
imap <right> <nop>

" Treat .ru Gemfile .pp files with as Ruby
au BufNewFile,BufRead Gemfile set filetype=ruby
au BufNewFile,BufRead *.ru set filetype ruby
au BufNewFile,BufRead *.pp set filetype ruby

" This will fix color for Putty
if &term == "xterm"
  set t_Co=256
  colorscheme Tomorrow-Night-Eighties
  " Airline symbols
  let g:airline_left_sep = '<'
  let g:airline_right_sep = '>'
  let g:airline_linecolumn_prefix = ''
  let g:airline_paste_symbol = ''
  let g:airline_paste_symbol = ''
endif

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
