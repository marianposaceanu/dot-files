if exists('g:loaded_git_helpers')
  finish
endif
let g:loaded_git_helpers = 1

" Resolve Git relative to the current file, even when Vim's cwd is elsewhere.
function! s:git(args) abort
  return system('git -C ' . shellescape(expand('%:p:h')) . ' ' . a:args)
endfunction

function! s:git_failed(output) abort
  if v:shell_error
    echohl WarningMsg
    echo 'Git: ' . trim(a:output)
    echohl None
    return 1
  endif
  return 0
endfunction

function! s:github_repo_url() abort
  let remote = trim(s:git('config --get remote.origin.url'))
  if v:shell_error
    return ''
  endif
  let remote = substitute(remote, '^git@github\.com:', 'https://github.com/', '')
  let remote = substitute(remote, '^ssh://git@github\.com/', 'https://github.com/', '')
  return remote =~# '^https://github\.com/' ? substitute(remote, '\.git$', '', '') : ''
endfunction

function! s:show_commit(hash, details) abort
  if a:hash !~# '^\x\{40\}$' && a:hash !~# '^\x\{64\}$'
    echo 'Git returned an invalid commit hash'
    return
  endif
  let url = s:github_repo_url()
  echohl Directory
  echo 'Commit: ' . (empty(url) ? a:hash : url . '/commit/' . a:hash)
  echohl None
  echo a:details
endfunction

function! GitBlameWithCommitMessageAndAuthor() abort
  if empty(expand('%'))
    echo 'Save the buffer before using Git helpers'
    return
  endif
  let output = s:git('blame --porcelain -L ' . line('.') . ',' . line('.') . ' -- ' . shellescape(expand('%:t')))
  if s:git_failed(output)
    return
  endif
  let hash = matchstr(output, '^\x\+')
  if hash =~# '^0\+$'
    echo 'Not committed yet'
    return
  endif
  if hash !~# '^\x\{40\}$' && hash !~# '^\x\{64\}$'
    echo 'Git returned an invalid commit hash'
    return
  endif
  let details = s:git('show --no-patch --no-notes --format=' . shellescape('%h (%an) %s') . ' ' . hash)
  if !s:git_failed(details)
    call s:show_commit(hash, details)
  endif
endfunction

command! Blame call GitBlameWithCommitMessageAndAuthor()

function! GitLogSearchByLineOrSelection() range abort
  if empty(expand('%'))
    echo 'Save the buffer before using Git helpers'
    return
  endif
  let term = join(getline(a:firstline, a:lastline), "\n")
  let output = s:git('log --reverse --format=' . shellescape('%H %h (%an) %s') . ' -S ' . shellescape(term) . ' -- ' . shellescape(expand('%:t')))
  if s:git_failed(output)
    return
  endif
  if empty(trim(output))
    echo 'No commits found for the search term'
    return
  endif
  call s:show_commit(matchstr(output, '^\x\+'), output)
endfunction

command! -range LogSearch <line1>,<line2>call GitLogSearchByLineOrSelection()
xnoremap <leader>gs :LogSearch<CR>
nnoremap <leader>gs :LogSearch<CR>
