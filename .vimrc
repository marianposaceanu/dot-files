set nocompatible

syntax on

" OSX Faster performance
" ---------------------------------|
" notes tweak the key repeat and latency with https://pqrs.org/osx/karabiner/
set lazyredraw                    " more info: https://github.com/tpope/vim-sensible/issues/78
set ttyfast
set ttyscroll=3
set ttymouse=xterm2
set regexpengine=1


" Theme
" ---------------------------------|
" set background=dark

" If using a Base16 terminal theme designed to keep the 16 ANSI colors intact (a "256" variation)
" and have sucessfully modified your 256 colorspace with base16-shell you'll need to add the following
" to your ~/.vimrc before the colorsheme declaration.
" via: https://github.com/chriskempson/base16-vim#256-colorspace
" let base16colorspace=256

" Ruby is an oddball in the family, use special spacing/rules
autocmd FileType ruby setlocal ts=2 sts=2 sw=2 norelativenumber nocursorline

" Theme colors
" ---------------------------------|
" colorscheme solarized
" colorscheme monokai              " requires https://github.com/crusoexia/vim-monokai
" colorscheme base16-railscasts    " requires https://github.com/chriskempson/base16-shell into .zshrc
" colorscheme molokai
set termguicolors                  " enable true colors support
let ayucolor="dark"                " for dark version of theme
" let ayucolor="light"               " for light version of theme
" let ayucolor="mirage"              " for mirage version of theme
colorscheme ayu

filetype plugin indent on          " Enable file type detection and do language-dependent indenting.

set pastetoggle=<F2>               " Toggle paste mode with F2 for easier pasting.
set synmaxcol=200                  " Limit syntax highlighting to 200 columns for performance.
set number                         " Display line numbers.
set hlsearch                       " Highlight search matches.
set showmatch                      " Briefly jump to matching bracket when inserting one.
set incsearch                      " Highlight matches as you type during a search.
set autoindent                     " Copy indent from the current line when starting a new line.
set history=1000                   " Keep 1000 lines of command line history.
set undolevels=1000                " Allow 1000 levels of undo.
set cursorline                     " Highlight the line with the cursor.
set expandtab                      " Use spaces instead of tabs.
set autochdir                      " Automatically change the current working directory to the file being edited.
set backspace=indent,eol,start     " Allow intuitive backspacing in insert mode.
set ignorecase                     " Case-insensitive searching by default.
set smartcase                      " Case-sensitive search if the search pattern contains uppercase letters.
set scrolloff=3                    " Keep 3 lines visible above and below the cursor.
set laststatus=2                   " Always show the status line.
set encoding=utf-8                 " Use UTF-8 encoding for files.
set nowrap                         " Disable line wrapping, display long lines as one line.
set ttimeoutlen=50                " fix for slow after INSERT exit mode
" set linebreak                     " ^

set nobackup                      " Don't make a backup.
set nowritebackup                 " And again.
set dir=~/tmp                     " save swp files into tmp
set noswapfile

set expandtab                     " Use spaces instead of tabs
set tabstop=2                     " Global tab width.
set shiftwidth=2                  " And again, related.
set softtabstop=2                 " This makes the backspace key treat the two
                                  "  spaces like a tab (so one backspace goes
                                  "  back a full 2 spaces).


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

                                              " Detect the system architecture and set the runtime path accordingly
let s:arch = system('uname -m')               " Check the system architecture
let s:arch = trim(s:arch)                     " Remove the trailing newline character
" echom "Detected architecture: " . s:arch    " Debug message to check the architecture
if s:arch == "arm64"                          " Apple Silicon (ARM)
    execute 'set rtp+=/opt/homebrew/opt/fzf'
elseif s:arch == "x86_64"                     " x86
    execute 'set rtp+=/usr/local/opt/fzf'
else
    echom "Unknown architecture: " . s:arch
endif

nnoremap <C-p> :Files<CR>

" Airline settings
" ---------------------------------|
" Set the theme
let g:airline_theme='simple'

" Enable powerline fonts
let g:airline_powerline_fonts = 1

" Disable default sections
let g:airline_section_a = ''
let g:airline_section_b = ''
let g:airline_section_c = ''
let g:airline_section_x = ''
let g:airline_section_y = ''
let g:airline_section_z = ''

" Customize sections
let g:airline_section_a = airline#section#create(['mode'])
let g:airline_section_c = airline#section#create(['%f'])
let g:airline_section_x = airline#section#create(['%p%%'])
let g:airline_section_y = airline#section#create(['fileformat', 'fileencoding'])  " Including file encoding
let g:airline_section_z = airline#section#create(['linenr', ':%c'])

" Disable unused extensions
let g:airline#extensions#branch#enabled = 0
let g:airline#extensions#hunks#enabled = 0
let g:airline#extensions#syntastic#enabled = 0
let g:airline#extensions#tagbar#enabled = 0
let g:airline#extensions#tabline#enabled = 0

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
