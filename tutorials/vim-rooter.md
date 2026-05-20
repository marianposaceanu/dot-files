# vim-rooter

Automatically changes Vim's working directory to the project root when you open a file. Works silently in the background.

---

## What it does

When you open a file, vim-rooter walks up the directory tree to find a root marker and runs `:cd` to that directory. This means:

- `:Files` and `<C-p>` search from the project root, not wherever you launched Vim
- `:Rg` / `<leader>a` searches the whole project
- `:Git` (fugitive) works correctly regardless of which subdirectory you opened from

---

## Root markers

By default vim-rooter looks for these markers (in order):

```
.git  .git/  _darcs  .hg  .bzr  .svn  Makefile  package.json
```

The first ancestor directory containing any of these is the root.

---

## Useful commands

| Command | Action |
|---------|--------|
| `:Rooter` | Manually trigger root detection for the current file |
| `:pwd` | Confirm the current working directory |

---

## When it doesn't find a root

If no root marker is found, vim-rooter changes to the file's own directory instead of leaving the cwd unchanged. This keeps relative paths predictable.

---

## Why it matters in this setup

The FZF default command is:

```vim
let $FZF_DEFAULT_COMMAND='git ls-files --exclude-standard -co'
```

Without vim-rooter, this command would only list files under whichever directory Vim happened to start in. With vim-rooter, it always lists files from the project root.
