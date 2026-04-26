if exists('g:loaded_git_helpers')
  finish
endif
let g:loaded_git_helpers = 1

function! s:github_repo_url() abort
  let remote_url = system('git config --get remote.origin.url')
  let remote_url = substitute(remote_url, '\n\+$', '', '')
  let github_repo_url = substitute(remote_url, '\.git$', '', '')
  let github_repo_url = substitute(github_repo_url, 'git@github\.com:', 'https://github.com/', '')
  return github_repo_url
endfunction

function! GitBlameWithCommitMessageAndAuthor() abort
  let current_line = line('.')
  let filename = expand('%')
  let blame_cmd = 'git blame -l -L' . current_line . ',' . current_line . ' -- ' . shellescape(filename)
  let blame_output = system(blame_cmd)
  let commit_hash = split(blame_output)[0]

  if commit_hash !~ '^0\+\|^\s*$'
    let show_cmd = 'git show --no-patch --no-notes --pretty=format:"%h (%an) %s" ' . commit_hash
    let show_output = system(show_cmd)
    let commit_url = s:github_repo_url() . '/commit/' . commit_hash

    echohl Directory
    echo 'Commit: '
    echohl Underlined
    echo commit_url
    echohl None
    echo ' - ' . show_output
    echohl None
  else
    echo 'Not committed yet'
  endif
endfunction

command! Blame call GitBlameWithCommitMessageAndAuthor()

function! GitLogSearchByLineOrSelection(...) range abort
  let search_term = ''

  if a:firstline != a:lastline || mode() ==# 'v'
    let lines = getline(a:firstline, a:lastline)
    let search_term = join(lines, ' ')
  else
    let search_term = getline('.')
  endif

  let search_term = shellescape(search_term)
  let filename = expand('%')
  let log_cmd = 'git log --reverse -S' . search_term . ' -- ' . shellescape(filename)
  let log_output = system(log_cmd)

  if empty(log_output)
    echo 'No commits found for the search term'
  else
    let commit_hash = split(log_output)[1]
    let commit_url = s:github_repo_url() . '/commit/' . commit_hash

    echohl Directory
    echo 'Commit: '
    echohl Underlined
    echo commit_url
    echohl None
    echo ' - ' . log_output
    echohl None
  endif
endfunction

command! -range LogSearch <line1>,<line2>call GitLogSearchByLineOrSelection(<line1>, <line2>)
vnoremap <leader>gs :<C-U>call GitLogSearchByLineOrSelection('<','>')<CR>
nnoremap <leader>gs :call GitLogSearchByLineOrSelection()<CR>
