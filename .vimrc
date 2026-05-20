set nocompatible

syntax on

" OSX Faster performance
" ---------------------------------|
" notes tweak the key repeat and latency with https://pqrs.org/osx/karabiner/
set lazyredraw                    " more info: https://github.com/tpope/vim-sensible/issues/78
" ttyfast/ttyscroll removed — deprecated no-ops since Vim 8
if has('mouse_sgr')
  set ttymouse=sgr                " SGR protocol supports terminals wider than 223 columns
endif


" Theme
" ---------------------------------|
" set background=dark

" If using a Base16 terminal theme designed to keep the 16 ANSI colors intact (a "256" variation)
" and have sucessfully modified your 256 colorspace with base16-shell you'll need to add the following
" to your ~/.vimrc before the colorsheme declaration.
" via: https://github.com/chriskempson/base16-vim#256-colorspace
" let base16colorspace=256

" Ruby is an oddball in the family, use special spacing/rules
augroup ruby_settings
  autocmd!
  autocmd FileType ruby setlocal ts=2 sts=2 sw=2 norelativenumber nocursorline
augroup END

" Theme colors
" ---------------------------------|
" colorscheme solarized
" colorscheme base16-railscasts    " requires https://github.com/chriskempson/base16-shell into .zshrc
" colorscheme molokai
set termguicolors                  " enable true colors support
let ayucolor="dark"                " for dark version of theme
" let ayucolor="light"               " for light version of theme
" let ayucolor="mirage"              " for mirage version of theme
colorscheme ayu

filetype plugin indent on          " Enable file type detection and do language-dependent indenting.

set wildmenu                       " Enhanced command-line completion.
set wildmode=list:longest,full     " Complete to longest common string, then cycle.
set hidden                         " Allow switching away from modified buffers without saving.
set synmaxcol=800                  " Limit syntax highlighting to 800 columns for better performance.
set number                         " Display line numbers.
set hlsearch                       " Highlight search matches.
set showmatch                      " Briefly jump to matching bracket when inserting one.
set incsearch                      " Highlight matches as you type during a search.
set autoindent                     " Copy indent from the current line when starting a new line.
set history=1000                   " Keep 1000 lines of command line history.
set undolevels=1000                " Allow 1000 levels of undo.
set expandtab                      " Use spaces instead of tabs.
" set autochdir                    " Keep cwd stable for better plugin/tool behavior.
set backspace=indent,eol,start     " Allow intuitive backspacing in insert mode.
set ignorecase                     " Case-insensitive searching by default.
set smartcase                      " Case-sensitive search if the search pattern contains uppercase letters.
set scrolloff=3                    " Keep 3 lines visible above and below the cursor.
set laststatus=2                   " Always show the status line.
set cursorlineopt=number           " Highlight only the line number for the cursor line.
set encoding=utf-8                 " Use UTF-8 encoding for files.
set nowrap                         " Disable line wrapping, display long lines as one line.
set fillchars+=eob:.               " Show end-of-buffer lines as dots.
set ttimeoutlen=50                " fix for slow after INSERT exit mode
" set linebreak                     " ^

set nobackup                      " Don't make a backup.
set nowritebackup                 " And again.
set noswapfile

set tabstop=2                     " Global tab width.
set shiftwidth=2                  " And again, related.
set softtabstop=2                 " This makes the backspace key treat the two
                                  "  spaces like a tab (so one backspace goes
                                  "  back a full 2 spaces).

" Large file performance guardrails
augroup large_file_perf
  autocmd!
  autocmd BufReadPre * if getfsize(expand('%:p')) > 1024 * 1024 | let b:large_file = 1 | endif
  autocmd BufReadPost * if exists('b:large_file') | setlocal syntax=OFF nocursorline | endif
augroup END

" Cursorline only in active window
augroup active_cursorline
  autocmd!
  autocmd WinEnter,BufEnter * setlocal cursorline
  autocmd WinLeave * setlocal nocursorline
augroup END


" NERDTree settings
" ---------------------------------|
nnoremap <C-n> :packadd nerdtree <Bar> NERDTreeToggle<CR>

augroup tabular_lazy
  autocmd!
  autocmd CmdUndefined Tabularize packadd tabular
augroup END

augroup fugitive_lazy
  autocmd!
  autocmd CmdUndefined Git,G,Gstatus,Gblame,Glog,Gclog,Gwrite,Gread,Gdiffsplit,Gvdiffsplit,GBrowse packadd fugitive
augroup END

augroup bufexplorer_lazy
  autocmd!
  autocmd CmdUndefined BufExplorer,BufExplorerHorizontalSplit,BufExplorerVerticalSplit packadd bufexplorer
augroup END

function! s:BcloseCommand(args, bang) abort
  if !exists('loaded_bclose')
    packadd bclose
  endif
  if !exists('loaded_bclose')
    echoerr 'bclose plugin not available'
    return
  endif
  let cmd = 'Bclose' . (a:bang ? '!' : '')
  if a:args !=# ''
    let cmd .= ' ' . a:args
  endif
  execute cmd
endfunction
command! -bang -complete=buffer -nargs=? Bclose call <SID>BcloseCommand(<q-args>, <bang>0)

" FZF settings
" ---------------------------------|
" https://github.com/junegunn/fzf/blob/master/README-VIM.md
" https://github.com/junegunn/fzf.vim/issues/248
" let g:fzf_layout = { 'down': '20%' }
" let g:fzf_layout = { 'window': '-tabnew' }
" center fzf pop-up IDE-style
let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.6 } }
let $FZF_DEFAULT_OPTS='--reverse'
let $FZF_DEFAULT_COMMAND='git ls-files --exclude-standard -co'

if isdirectory('/opt/homebrew/opt/fzf')
  set rtp+=/opt/homebrew/opt/fzf
elseif isdirectory('/usr/local/opt/fzf')
  set rtp+=/usr/local/opt/fzf
endif

nnoremap <C-p> :Files<CR>

" FZF git shortcuts
" ---------------------------------|
" <leader>gc — browse per-file commit history with diff preview
nnoremap <leader>gc :BCommits<CR>

" GitGutter settings
" ---------------------------------|
" Reduce updatetime so signs refresh promptly (also speeds up CursorHold)
set updatetime=250
" Use a clean single-char sign column (always visible to prevent layout shift)
set signcolumn=yes
let g:gitgutter_sign_added    = '▎'
let g:gitgutter_sign_modified = '▎'
let g:gitgutter_sign_removed  = '▁'

" Lightline settings
" ---------------------------------|
let g:lightline = {
      \ 'colorscheme': 'ayu_dark',
      \ 'active': {
      \   'left': [ [ 'mode' ], [ 'readonly', 'filename', 'modified' ] ],
      \   'right': [ [ 'percent' ], [ 'lineinfo' ], [ 'fileformat', 'fileencoding' ] ]
      \ }
      \ }

" Toogle search highlighting
" ---------------------------------|
nnoremap <F3> :set hlsearch!<CR>

" Toggle spell check with <F5>
" ---------------------------------|
nnoremap <F5> :setlocal spell! spelllang=en_us<cr>
imap <F5> <ESC>:setlocal spell! spelllang=en_us<cr>

" Toogle alternate shortcut for BuffExplorer
"  explore/next/previous: Alt-F12, F12, Shift-F12.
" ---------------------------------|
nnoremap <silent> <M-F12> :BufExplorer<CR>
nnoremap <silent> <F12> :bn<CR>
nnoremap <silent> <S-F12> :bp<CR>
nnoremap <silent> <leader>be :BufExplorer<CR>
nnoremap <silent> <leader>bs :BufExplorerHorizontalSplit<CR>
nnoremap <silent> <leader>bv :BufExplorerVerticalSplit<CR>
nnoremap <silent> <leader>bd :Bclose<CR>

" Ripgrep configs (fzf.vim)
" ---------------------------------|
nnoremap <leader>a :Rg<space>
nnoremap <leader>A :Rg <C-r><C-w><CR>

" Sorting words (not lines) in VIM
"  via http://stackoverflow.com/questions/1327978/sorting-words-not-lines-in-vim
"  moved off F2 (conflicts with pastetoggle) to <leader>sw
vnoremap <leader>sw d:execute 'normal i' . join(sort(split(getreg('"'))), ' ')<CR>

" Check code complexity and duplication for current file
if has("gui_win32")
  nnoremap <leader>x :!cls &&
        \ echo '----- Complexity -----' && flog % &&
        \ echo '----- Duplication -----' && flay %<cr>
else
  nnoremap <leader>x :!clear &&
        \ echo '----- Complexity -----' && flog % &&
        \ echo '----- Duplication -----' && flay %<cr>
end

" OSX Vim clipboard fixes
"  set clipboard=unnamed makes the unnamed register mirror the system clipboard;
"  explicit "+ mappings below are redundant when this is set — removed.
" set clipboard=unnamed
"  note: vim needs to be compiled with --enable-clipboard, --enable-xterm_clipboard
"  you can easily add them via: brew edit vim
" yank text to OS X clipboard
" http://evertpot.com/osx-tmux-vim-copy-paste-clipboard/
set clipboard=unnamed

" no more .netrwhist file
let g:netrw_dirhistmax = 0

" Bye bye arrow keys
" ---------------------------------|
nnoremap <up> <nop>
nnoremap <down> <nop>
nnoremap <left> <nop>
nnoremap <right> <nop>
inoremap <up> <nop>
inoremap <down> <nop>
inoremap <left> <nop>
inoremap <right> <nop>

" Golden View
let g:goldenview__enable_default_mapping = 0
function! s:ToggleGoldenView() abort
  packadd GoldenView.Vim
  execute 'GoldenViewToggle'
endfunction
nnoremap <leader>gv :call <SID>ToggleGoldenView()<CR>

" fix slow JRuby loading via: https://github.com/vim-ruby/vim-ruby/issues/33
if !empty(matchstr($MY_RUBY_HOME, 'jruby'))
  let g:ruby_path = '/usr/bin/ruby'
endif


" via https://vim.fandom.com/wiki/Repeat_command_on_each_line_in_visual_block
" allow the . to execute once for each line of a visual selection
vnoremap . :normal .<CR>
" make ` execute the contents of the a register
nnoremap ` @a
vnoremap ` :normal @a<CR>

" Use ctrl-[hjkl] to select the active split!
" via https://stackoverflow.com/questions/6053301/easier-way-to-navigate-between-vim-split-panes
"     https://vim.fandom.com/wiki/Switch_between_Vim_window_splits_easily
nnoremap <silent> <c-k> :wincmd k<CR>
nnoremap <silent> <c-j> :wincmd j<CR>
nnoremap <silent> <c-h> :wincmd h<CR>
nnoremap <silent> <c-l> :wincmd l<CR>

" Map .json.jbuilder files to Ruby syntax
augroup jbuilder_syntax
  autocmd!
  autocmd BufNewFile,BufRead *.json.jbuilder set syntax=ruby
augroup END
