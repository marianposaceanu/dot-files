" Vimball Archiver by Charles E. Campbell, Jr., Ph.D.
UseVimball
finish
autoload/ShowTrailingWhitespace.vim	[[[1
110
" ShowTrailingWhitespace.vim: Detect unwanted whitespace at the end of lines.
"
" DEPENDENCIES:
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.00.004	06-Mar-2012	Toggle to value 2 when enabled but the buffer is
"				filtered from showing trailing whitespace.
"	003	05-Mar-2012	Introduce g:ShowTrailingWhitespace_FilterFunc to
"				disable highlighting for non-persisted and
"				nomodifiable buffers.
"	002	02-Mar-2012	Introduce b:ShowTrailingWhitespace_ExtraPattern
"				to be able to avoid some matches (e.g. a <Space>
"				in column 1 in a buffer with filetype=diff) and
"				ShowTrailingWhitespace#SetLocalExtraPattern() to
"				set it.
"	001	25-Feb-2012	file creation
let s:save_cpo = &cpo
set cpo&vim

function! ShowTrailingWhitespace#Pattern( isInsertMode )
    return (exists('b:ShowTrailingWhitespace_ExtraPattern') ? b:ShowTrailingWhitespace_ExtraPattern : '') .
    \	(a:isInsertMode ? '\s\+\%#\@<!$' : '\s\+$')
endfunction
let s:HlGroupName = 'ShowTrailingWhitespace'
function! s:UpdateMatch( isInsertMode )
    let l:pattern = ShowTrailingWhitespace#Pattern(a:isInsertMode)
    if exists('w:ShowTrailingWhitespace_Match')
	" Info: matchadd() does not consider the 'magic' (it's always on),
	" 'ignorecase' and 'smartcase' settings.
	silent! call matchdelete(w:ShowTrailingWhitespace_Match)
	call matchadd(s:HlGroupName, pattern, -1, w:ShowTrailingWhitespace_Match)
    else
	let w:ShowTrailingWhitespace_Match =  matchadd(s:HlGroupName, pattern)
    endif
endfunction
function! s:DeleteMatch()
    if exists('w:ShowTrailingWhitespace_Match')
	silent! call matchdelete(w:ShowTrailingWhitespace_Match)
	unlet w:ShowTrailingWhitespace_Match
    endif
endfunction

function! s:DetectAll()
    let l:currentWinNr = winnr()

    " By entering a window, its height is potentially increased from 0 to 1 (the
    " minimum for the current window). To avoid any modification, save the window
    " sizes and restore them after visiting all windows.
    let l:originalWindowLayout = winrestcmd()

    noautocmd windo call ShowTrailingWhitespace#Detect(0)
    execute l:currentWinNr . 'wincmd w'
    silent! execute l:originalWindowLayout
endfunction

function! ShowTrailingWhitespace#IsSet()
    return (exists('b:ShowTrailingWhitespace') ? b:ShowTrailingWhitespace : g:ShowTrailingWhitespace)
endfunction
function! ShowTrailingWhitespace#NotFiltered()
    let l:Filter = (exists('b:ShowTrailingWhitespace_FilterFunc') ? b:ShowTrailingWhitespace_FilterFunc : g:ShowTrailingWhitespace_FilterFunc)
    return (empty(l:Filter) ? 1 : call(l:Filter, []))
endfunction

function! ShowTrailingWhitespace#Detect( isInsertMode )
    if ShowTrailingWhitespace#IsSet() && ShowTrailingWhitespace#NotFiltered()
	call s:UpdateMatch(a:isInsertMode)
    else
	call s:DeleteMatch()
    endif
endfunction

" The showing of trailing whitespace be en-/disabled globally or only for a particular buffer.
function! ShowTrailingWhitespace#Set( isTurnOn, isGlobal )
    if a:isGlobal
	let g:ShowTrailingWhitespace = a:isTurnOn
	call s:DetectAll()
    else
	let b:ShowTrailingWhitespace = a:isTurnOn
	call ShowTrailingWhitespace#Detect(0)
    endif
endfunction
function! ShowTrailingWhitespace#Reset()
    unlet! b:ShowTrailingWhitespace
    call ShowTrailingWhitespace#Detect(0)
endfunction
function! ShowTrailingWhitespace#Toggle( isGlobal )
    if a:isGlobal
	let l:newState = ! g:ShowTrailingWhitespace
    else
	if ShowTrailingWhitespace#NotFiltered()
	    let l:newState = ! ShowTrailingWhitespace#IsSet()
	else
	    let l:newState = (ShowTrailingWhitespace#IsSet() > 1 ? 0 : 2)
	endif
    endif

    call ShowTrailingWhitespace#Set(l:newState, a:isGlobal)
endfunction

function! ShowTrailingWhitespace#SetLocalExtraPattern( pattern )
    let b:ShowTrailingWhitespace_ExtraPattern = a:pattern
    call s:DetectAll()
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
autoload/ShowTrailingWhitespace/Filter.vim	[[[1
30
" ShowTrailingWhitespace/Filter.vim: Exclude certain buffers from detection.
"
" DEPENDENCIES:
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.00.002	06-Mar-2012	Modularize conditionals.
"				Also do not normally show 'binary' buffers.
"	001	05-Mar-2012	file creation

function! s:IsPersistedBuffer()
    return ! (&l:buftype ==# 'nofile' || &l:buftype ==# 'nowrite')
endfunction
function! s:IsScratchBuffer()
    return (bufname('') =~# '\[Scratch]')
endfunction
function! s:IsForcedShow()
    return (ShowTrailingWhitespace#IsSet() == 2)
endfunction

function! ShowTrailingWhitespace#Filter#Default()
    let l:isShownNormally = &l:modifiable && ! &l:binary && (s:IsPersistedBuffer() || s:IsScratchBuffer())
    return l:isShownNormally || s:IsForcedShow()
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
plugin/ShowTrailingWhitespace.vim	[[[1
51
" ShowTrailingWhitespace.vim: Detect unwanted whitespace at the end of lines.
"
" DEPENDENCIES:
"   - ShowTrailingWhitespace.vim autoload script.
"   - ShowTrailingWhitespace/Filter.vim autoload script.
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.00.002	26-Feb-2012	Move functions to autoload script.
"				Rewrite example commands with new autoload
"				functions.
"	001	25-Feb-2012	file creation

" Avoid installing twice or when in unsupported Vim version.
if exists('g:loaded_ShowTrailingWhitespace') || (v:version == 701 && ! exists('*matchadd')) || (v:version < 701)
    finish
endif
let g:loaded_ShowTrailingWhitespace = 1

"- configuration ---------------------------------------------------------------

if ! exists('g:ShowTrailingWhitespace')
    let g:ShowTrailingWhitespace = 1
endif
if ! exists('g:ShowTrailingWhitespace_FilterFunc')
    if v:version < 702
	" Vim 7.0/1 need preloading of functions referenced in Funcrefs.
	runtime autoload/ShowTrailingWhitespace/Filter.vim
    endif
    let g:ShowTrailingWhitespace_FilterFunc = function('ShowTrailingWhitespace#Filter#Default')
endif


"- autocmds --------------------------------------------------------------------

augroup ShowTrailingWhitespace
    autocmd!
    autocmd BufWinEnter,InsertLeave * call ShowTrailingWhitespace#Detect(0)
    autocmd InsertEnter             * call ShowTrailingWhitespace#Detect(1)
augroup END


"- highlight groups ------------------------------------------------------------

highlight def link ShowTrailingWhitespace Error

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
ftplugin/diff_ShowTrailingWhitespace.vim	[[[1
17
" diff_ShowTrailingWhitespace.vim: Whitespace exceptions for the "diff" filetype.
"
" DEPENDENCIES:
"   - ShowTrailingWhitespace.vim autoload script.
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.00.001	02-Mar-2012	file creation

" A single space at the beginning of a line can represent an empty context line.
call ShowTrailingWhitespace#SetLocalExtraPattern( '^\%( \@!\s\)$\|\%>1v')

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
ftplugin/mail_ShowTrailingWhitespace.vim	[[[1
22
" mail_ShowTrailingWhitespace.vim: Whitespace exceptions for the "mail" filetype.
"
" DEPENDENCIES:
"   - ShowTrailingWhitespace.vim autoload script.
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"   1.00.002	16-Mar-2012	Refined pattern.
"	001	03-Mar-2012	file creation

" - The email signature separator consists of dash-dash-space.
" - Email headers from Outlook or the Thunderbird "External Editor" add-on
"   may leave whitespace after mail headers. Ignore them unless it's the
"   Subject: header.
" - Quoted empty lines may contain trailing whitespace.
call ShowTrailingWhitespace#SetLocalExtraPattern( '\%(^\%(--\|\%( \?>\)\+\|\%(From\|Sent\|To\|Cc\|Bcc\):.*\)\)\@<!')

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
doc/ShowTrailingWhitespace.txt	[[[1
162
*ShowTrailingWhitespace.txt*	Detect unwanted whitespace at the end of lines.

		  SHOW TRAILING WHITESPACE    by Ingo Karkat
						  *ShowTrailingWhitespace.vim*
description			|ShowTrailingWhitespace-description|
usage				|ShowTrailingWhitespace-usage|
installation			|ShowTrailingWhitespace-installation|
configuration			|ShowTrailingWhitespace-configuration|
integration			|ShowTrailingWhitespace-integration|
limitations			|ShowTrailingWhitespace-limitations|
known problems			|ShowTrailingWhitespace-known-problems|
todo				|ShowTrailingWhitespace-todo|
history				|ShowTrailingWhitespace-history|

==============================================================================
DESCRIPTION				  *ShowTrailingWhitespace-description*

This plugin highlights whitespace at the end of each line (except when typing
at the end of a line). It uses the matchadd()-function, therefore doesn't
interfere with syntax highlighting and leaves the |:match| command for other
uses.
Highlighting can be switched on/off globally and for individual buffers. The
plugin comes with exceptions for certain filetypes, where certain lines can /
must include trailing whitespace; additional patterns can be configured.

RELATED WORKS								     *

There are already a number of plugins for this purpose, most based on this
VimTip:
    http://vim.wikia.com/wiki/Highlight_unwanted_spaces
However, most of them use the older :match command and are not as flexible.
- smartmatcheol.vim (vimscript #2635) highlights based on file extension or
  name.
- trailing-whitespace (vimscript #3201) uses :match.
- bad-whitespace (vimscript #3735) uses :match, allows on/off/toggling via
  commands.
- Trailer Trash (vimscript #3938) uses :match.
- DynamicSigns (vimscript #3965) can show whitespace errors (also mixed
  indent) in the sign column.

Many plugins also come with a command to strip off the trailing whitespace;
this plugin separates this into the companion |DeleteTrailingWhitespace.vim|
plugin (vimscript #0000), which can even remove the trailing whitespace
automatically on each write.

To quickly locate the occurrences of trailing whitespace, you can use the
companion |JumpToTrailingWhitespace.vim| plugin (vimscript #0000).

==============================================================================
USAGE						*ShowTrailingWhitespace-usage*

By default, trailing whitespace is highlighted in all Vim buffers. Some users
may want to selectively enable / disable this for certain filetypes, or files
in a particular directory hierarchy, or toggle this on demand. Since it's
difficult to accommodate all these demands with short and easy mappings and
commands, this plugin does not define any of them, and leaves it to you to
tailor the plugin to your needs. See |ShowTrailingWhitespace-configuration|
below.

==============================================================================
INSTALLATION				 *ShowTrailingWhitespace-installation*

This script is packaged as a |vimball|. If you have the "gunzip" decompressor
in your PATH, simply edit the *.vba.gz package in Vim; otherwise, decompress
the archive first, e.g. using WinZip. Inside Vim, install by sourcing the
vimball or via the |:UseVimball| command. >
    vim ShowTrailingWhitespace.vba.gz
    :so %
To uninstall, use the |:RmVimball| command.

DEPENDENCIES				 *ShowTrailingWhitespace-dependencies*

- Requires Vim 7.1 with "matchadd()", or Vim 7.2 or higher.

==============================================================================
CONFIGURATION				*ShowTrailingWhitespace-configuration*

For a permanent configuration, put the following commands into your |vimrc|:

					       *ShowTrailingWhitespace-colors*
To change the highlighting colors: >
    highlight ShowTrailingWhitespace Error ctermbg=Red guibg=Red
<
						    *g:ShowTrailingWhitespace*
By default, highlighting is enabled for all buffers, and you can (selectively)
disable it. To work from the opposite premise, launch Vim with highlighting
disabled: >
    let g:ShowTrailingWhitespace = 0
<
					 *g:ShowTrailingWhitespace_FilterFunc*
In addition to toggling the highlighting on/off via
|g:ShowTrailingWhitespace|, the decision can also be influenced by buffer
settings or the environment. By default, buffers that are not persisted to
disk (unless they are scratch buffers) or not modifiable (like user interface
windows from various plugins) are skipped. You can disable this filtering: >
    let g:ShowTrailingWhitespace_FilterFunc = ''
or install your own custom filter function instead: >
    let g:ShowTrailingWhitespace_FilterFunc = function('MyFunc')
<

					     *ShowTrailingWhitespace-commands*
Highlighting can be enabled / disabled globally and for individual buffers.
Analog to the |:set| and |:setlocal| commands, you can define the following
commands: >
    command! -bar ShowTrailingWhitespaceOn          call ShowTrailingWhitespace#Set(1,1)
    command! -bar ShowTrailingWhitespaceOff         call ShowTrailingWhitespace#Set(0,1)
    command! -bar ShowTrailingWhitespaceBufferOn    call ShowTrailingWhitespace#Set(1,0)
    command! -bar ShowTrailingWhitespaceBufferOff   call ShowTrailingWhitespace#Set(0,0)
To set the local highlighting back to its global value (like :set {option}<
does), the following command can be defined: >
    command! -bar ShowTrailingWhitespaceBufferClear call ShowTrailingWhitespace#Reset()
<
					     *ShowTrailingWhitespace-mappings*
You can also define a quick mapping to toggle the highlighting (here, locally;
for global toggling use ShowTrailingWhitespace#Toggle(1): >
    nnoremap <silent> <Leader>t$ :<C-u>call ShowTrailingWhitespace#Toggle(0)<Bar>echo (ShowTrailingWhitespace#IsSet() ? 'Show trailing whitespace' : 'Not showing trailing whitespace')<CR>
<
					   *ShowTrailingWhitespace-exceptions*
For some filetypes, in certain places, trailing whitespace is part of the
syntax or even mandatory. If you don't want to be bothered by these showing up
as false positives, you can augment the regular expression so that these
places do not match. The ShowTrailingWhitespace#SetLocalExtraPattern()
function takes a regular expression that is prepended to the pattern for the
trailing whitespace. For a certain filetype, this is best set in a file
    ftplugin/{filetype}_ShowTrailingWhitespace.vim


==============================================================================
INTEGRATION				  *ShowTrailingWhitespace-integration*
					    *ShowTrailingWhitespace-functions*
The ShowTrailingWhitespace#IsSet() function can be used to query the on/off
status for the current buffer, e.g. for use in the |statusline|.

To obtain the pattern for matching trailing whitespace, including any
|ShowTrailingWhitespace-exceptions|, you can use the function
ShowTrailingWhitespace#Pattern(0).

==============================================================================
LIMITATIONS				  *ShowTrailingWhitespace-limitations*

KNOWN PROBLEMS			       *ShowTrailingWhitespace-known-problems*

TODO						 *ShowTrailingWhitespace-todo*

IDEAS						*ShowTrailingWhitespace-ideas*

==============================================================================
HISTORY					      *ShowTrailingWhitespace-history*

1.00	16-Mar-2012
First published version.

0.01	25-Feb-2012
Started development.

==============================================================================
Copyright: (C) 2012 Ingo Karkat
The VIM LICENSE applies to this script; see |copyright|.

Maintainer:	Ingo Karkat <ingo@karkat.de>
==============================================================================
 vim:tw=78:ts=8:ft=help:norl:
