# vim-gitgutter

Shows which lines you have added, modified, or removed since the last git commit, directly in the sign column.

```
▎ added line
▎ modified line
▁ removed below this line
```

---

## Navigating hunks

A **hunk** is a contiguous block of changed lines.

| Key | Action |
|-----|--------|
| `]c` | Jump to next hunk |
| `[c` | Jump to previous hunk |

---

## Working with hunks

| Key | Action |
|-----|--------|
| `<leader>hp` | Preview hunk diff in a floating window |
| `<leader>hs` | Stage hunk (without leaving Vim) |
| `<leader>hu` | Undo hunk (revert to HEAD) |

> Staging individual hunks is useful when a file has multiple unrelated changes
> and you want to commit them separately.

---

## Viewing commit history

| Key | Action |
|-----|--------|
| `<leader>gc` | Browse per-file commit history with diff preview (`:BCommits` via fzf) |
| `<leader>gs` | Search git log for the exact line or visual selection under cursor |

---

## Text objects

Gitgutter registers `ic` and `ac` as hunk text objects:

| Key | Action |
|-----|--------|
| `vic` | Select inside hunk (visual) |
| `vac` | Select around hunk (visual) |
| `dic` | Delete inside hunk |
| `yic` | Yank inside hunk |

---

## Commands

| Command | Action |
|---------|--------|
| `:GitGutterToggle` | Toggle signs on/off |
| `:GitGutterLineHighlightsToggle` | Toggle full-line background highlights |
| `:GitGutterFold` | Fold all unchanged lines (focus on the diff) |
| `:GitGutterQuickFix` | Load all hunks into the quickfix list |

---

## Config (from `.vimrc`)

```vim
set updatetime=250        " refresh signs within 250ms of stopping edits
set signcolumn=yes        " always show the sign column (prevents layout shift)
let g:gitgutter_sign_added    = '▎'
let g:gitgutter_sign_modified = '▎'
let g:gitgutter_sign_removed  = '▁'
```
