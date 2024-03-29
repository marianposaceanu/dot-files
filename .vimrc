set nocompatible

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
set background=dark

" If using a Base16 terminal theme designed to keep the 16 ANSI colors intact (a "256" variation)
" and have sucessfully modified your 256 colorspace with base16-shell you'll need to add the following
" to your ~/.vimrc before the colorsheme declaration.
" via: https://github.com/chriskempson/base16-vim#256-colorspace
" let base16colorspace=256

" Ruby is an oddball in the family, use special spacing/rules
if v:version >= 703
  " Note: Relative number is quite slow with Ruby, so is cursorline
  autocmd FileType ruby setlocal ts=2 sts=2 sw=2 norelativenumber nocursorline
else
  autocmd FileType ruby setlocal ts=2 sts=2 sw=2
endif

" Theme colors
" ---------------------------------|
" colorscheme solarized
colorscheme monokai              " requires https://github.com/crusoexia/vim-monokai
" colorscheme base16-railscasts    " requires https://github.com/chriskempson/base16-shell into .zshrc
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



" Windows separators
" ---------------------------------|
set fillchars=eob:\ ,fold:\ ,vert:\ 



" NERDTree settings
" ---------------------------------|
map <C-n> :NERDTreeToggle<CR>


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
set rtp+=/opt/homebrew/opt/fzf
nnoremap <C-p> :Files<CR>

" Airline settings
" ---------------------------------|
" let g:airline_theme="base16"
let g:airline_theme="simple"

" Disable olde fixes - cleaner look
" let g:airline_powerline_fonts = 1
" if !exists('g:airline_symbols')
"   let g:airline_symbols = {}
" endif
" unicode symbols
" let g:airline_left_sep = '»'
" let g:airline_left_sep = '▶'
" let g:airline_right_sep = '«'
" let g:airline_right_sep = '◀'
" let g:airline_symbols.linenr = '␊'
" let g:airline_symbols.linenr = '␤'
" let g:airline_symbols.linenr = '¶'
" let g:airline_symbols.branch = '⎇'
" let g:airline_symbols.paste = 'ρ'
" let g:airline_symbols.paste = 'Þ'
" let g:airline_symbols.paste = '∥'
" let g:airline_symbols.whitespace = 'Ξ'

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

" Ack configs
" ---------------------------------|
map <leader>a :Ack!<space>                             " Map Ack
map <leader>A :Ack! "<C-r>=expand('<cword>')<CR>"      " Search for word under cursor with ack

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

" Golden View
let g:goldenview__enable_default_mapping = 0

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
nmap <silent> <c-k> :wincmd k<CR>
nmap <silent> <c-j> :wincmd j<CR>
nmap <silent> <c-h> :wincmd h<CR>
nmap <silent> <c-l> :wincmd l<CR>

" Define a function that gets Git blame information, including the commit message and author, for the current line in a Vim buffer.
function! GitBlameWithCommitMessageAndAuthor()
    " Get the current line number.
    let current_line = line('.')
    " Get the current file name.
    let filename = expand('%')
    " Construct the git blame command for the current line.
    let blame_cmd = 'git blame -l -L' . current_line . ',' . current_line . ' -- ' . shellescape(filename)
    " Execute the git blame command and capture the output.
    let blame_output = system(blame_cmd)
    " Extract the commit hash from the git blame output.
    let commit_hash = split(blame_output)[0]

    " Check if a valid commit hash is found (not a series of zeros or empty).
    if commit_hash !~ '^0\+\|^\\s*$'
        " Construct the git show command to get commit details using the hash.
        let show_cmd = 'git show --no-patch --no-notes --pretty=format:"%h (%an) %s" ' . commit_hash
        " Execute the git show command and capture the output.
        let show_output = system(show_cmd)

        " Get the remote repository URL from git configuration.
        let remote_url_cmd = 'git config --get remote.origin.url'
        " Execute the command to get the remote URL and remove any trailing newline.
        let remote_url = system(remote_url_cmd)
        let remote_url = substitute(remote_url, '\n\+$', '', '') " Remove trailing newline
        " Transform the remote URL into a GitHub repository URL.
        let github_repo_url = substitute(remote_url, '\.git$', '', '')
        let github_repo_url = substitute(github_repo_url, 'git@github\.com:', 'https://github.com/', '')
        let github_repo_url = substitute(github_repo_url, 'https://', 'https://', '')

        " Construct the full GitHub URL for the specific commit.
        let commit_url = github_repo_url . '/commit/' . commit_hash

        " Display the commit URL and the commit details.
        echohl Directory
        echo "Commit: "
        echohl Underlined
        echo commit_url
        echohl None
        echo " - " . show_output
        echohl None
    else
        " Handle the case where the line is not yet committed.
        echo "Not committed yet"
    endif
endfunction

" Define a Vim command 'Blame' that calls the above function.
command! Blame call GitBlameWithCommitMessageAndAuthor()
