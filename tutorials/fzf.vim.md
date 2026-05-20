# fzf.vim

Fuzzy finder integration for files, buffers, git objects, and search results. Powered by fzf and ripgrep.

The popup opens centered at 90% width / 60% height. Press `Ctrl-/` to toggle the preview panel.

---

## Files

| Command / Key | Action |
|---------------|--------|
| `<C-p>` / `:Files` | Fuzzy-find all files in the repo |
| `:GFiles` | Files tracked by git (`git ls-files`) |
| `:GFiles?` | Files with uncommitted changes (`git status`) |

---

## Search inside files

| Command / Key | Action |
|---------------|--------|
| `<leader>a` | `:Rg` — open ripgrep prompt, type a query |
| `<leader>A` | `:Rg` pre-filled with the word under cursor |

Inside the ripgrep results window you can keep filtering the list by typing.

---

## Buffers and history

| Command | Action |
|---------|--------|
| `:Buffers` | Open buffer list |
| `:History` | Recently opened files |
| `:History:` | Command history |
| `:History/` | Search history |

---

## Git

| Command / Key | Action |
|---------------|--------|
| `<leader>gc` | `:BCommits` — commit history for the current file with diff preview |
| `:Commits` | Full repo commit history |

---

## Other

| Command | Action |
|---------|--------|
| `:Lines` | Fuzzy search across all open buffers |
| `:BLines` | Fuzzy search within the current buffer |
| `:Marks` | Jump to a Vim mark |
| `:Maps` | Search all active key mappings |

---

## Keys inside any fzf window

| Key | Action |
|-----|--------|
| `Ctrl-j` / `Ctrl-k` | Move down / up |
| `Ctrl-t` | Open in new tab |
| `Ctrl-x` | Open in horizontal split |
| `Ctrl-v` | Open in vertical split |
| `Ctrl-/` | Toggle preview panel |
| `Tab` | Mark multiple items |
| `Esc` | Close |
