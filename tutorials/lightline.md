# lightline.vim

A minimal, fast status line. Shows mode, file info, and position. Configured to use the `ayu_dark` colorscheme to match the editor theme.

---

## What the status line shows

```
[ MODE ]  filename [modified]  ...  percentage  line:col  format  encoding
```

| Section | Content |
|---------|---------|
| Left 1 | Current mode (NORMAL / INSERT / VISUAL …) |
| Left 2 | Read-only flag, filename, modified flag |
| Right 1 | Percentage through file |
| Right 2 | Line : column |
| Right 3 | File format, file encoding |

---

## Current config (from `.vimrc`)

```vim
let g:lightline = {
      \ 'colorscheme': 'ayu_dark',
      \ 'active': {
      \   'left':  [ [ 'mode' ], [ 'readonly', 'filename', 'modified' ] ],
      \   'right': [ [ 'percent' ], [ 'lineinfo' ], [ 'fileformat', 'fileencoding' ] ]
      \ }
      \ }
```

---

## Why `set laststatus=2`

The `.vimrc` sets `laststatus=2`, which means the status line is always visible even when only one window is open. Without this, lightline only appears in split views.

---

## Available colorschemes

Lightline ships with many built-in colorschemes. To preview one:

```vim
:let g:lightline.colorscheme = 'wombat'
:call lightline#init()
:call lightline#colorscheme()
:call lightline#update()
```

Other options: `powerline`, `jellybeans`, `solarized`, `one`, `nord`, `dracula`, `darcula`, `molokai`.
