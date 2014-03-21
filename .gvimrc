if has("gui_gtk2")
  set guifont=Consolas\ 14
elseif has("gui_macvim") || has("gui_win32")
  set guifont=Monaco:h16
end

set guioptions-=m  "remove menu bar
set guioptions-=T  "remove toolbar
set guioptions-=r  "remove right-hand scroll bar
set go-=L          "remove left-hand scroll bar

if has("gui_running") && has("gui_win32")
  au GUIEnter * simalt ~x " full screen

  " Windows support for Ctrl+[C,V]
  nmap <C-V> "+gP
  imap <C-V> <ESC><C-V>i
  vmap <C-C> "+y
else
  " This is console Vim.
  " if exists("+lines")
  "   set lines=50
  " endif
  " if exists("+columns")
  "   set columns=100
  " endif
endif

set lines=999 columns=9999
