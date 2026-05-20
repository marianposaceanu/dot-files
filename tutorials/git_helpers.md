# git_helpers (custom)

A small custom plugin (`plugin/git_helpers.vim`) that adds two git commands not covered by fugitive or fzf.vim.

---

## :Blame — inline blame for the current line

```
:Blame
```

Prints the commit hash, author, subject, and GitHub URL for the line under the cursor — all in the Vim message area without leaving the file.

Example output:

```
Commit:
https://github.com/you/repo/commit/3b753cf8
 - 3b753cf (Marian P) fix: handle edge case in parser
```

### How it differs from fugitive's `:Git blame`

| | `:Blame` (custom) | `:Git blame` (fugitive) |
|---|---|---|
| Output | Inline message, stays in current buffer | Opens a full interactive split |
| Navigation | None | Full commit browsing with `<Enter>` |
| Speed | Instant | Loads full blame for the file |

Use `:Blame` for a quick "who wrote this line?" check. Use `:Git blame` when you want to navigate the history.

---

## :LogSearch / `<leader>gs` — find which commit introduced a line

Searches `git log -S` (the "pickaxe") for the exact text of the current line or visual selection, then prints the first matching commit URL.

| Key / Command | Action |
|---------------|--------|
| `<leader>gs` | Search for current line (normal mode) |
| `<leader>gs` | Search for selected text (visual mode) |
| `:'<,'>LogSearch` | Same, via command |

### When to use it

Use `<leader>gs` when you want to know **which commit first added or removed a specific string**, rather than who last touched the line (that's `:Blame`). It is especially useful for tracking down when a particular value, function call, or bug was introduced.

Example: cursor on a line containing `MAX_RETRIES = 5`:

```
<leader>gs    →   finds the commit that first introduced that exact text
```

---

## Relation to vim-rhubarb's :GBrowse

Both tools build a GitHub URL, but for different purposes:

| Tool | Opens / shows |
|------|--------------|
| `:Blame` | Commit URL in the message area (stay in Vim) |
| `:GBrowse` | Opens file / line / commit in the browser |
| `<leader>gs` | Commit URL for the line's origin in the message area |
