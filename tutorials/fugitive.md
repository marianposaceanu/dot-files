# fugitive

Full git porcelain inside Vim. Lazy-loaded on first use of any `:Git` command.

---

## The status window

```
:Git
```

Opens a status buffer. Everything you need is one key away from here:

| Key | Action |
|-----|--------|
| `s` | Stage file / hunk under cursor |
| `u` | Unstage file / hunk |
| `=` | Toggle inline diff for file under cursor |
| `dv` | Open a vertical diff split |
| `cc` | Commit staged changes (opens message buffer) |
| `ca` | Amend last commit |
| `cz` | Stash |
| `X` | Discard change |
| `<Enter>` | Open file |
| `g?` | Show all available keys |

---

## Diff

| Command | Action |
|---------|--------|
| `:Gdiffsplit` | Vertical diff of current file vs index |
| `:Gdiffsplit HEAD` | Diff vs last commit |
| `:Gdiffsplit main` | Diff vs a branch |

In the diff view, use standard Vim diff motions:

| Key | Action |
|-----|--------|
| `]c` | Next difference |
| `[c` | Previous difference |
| `do` | Obtain change from other buffer |
| `dp` | Put change into other buffer |

---

## Blame

```
:Git blame
```

Opens an interactive blame split. Navigate with:

| Key | Action |
|-----|--------|
| `<Enter>` | Open the blamed commit |
| `o` | Open commit in a split |
| `~` | Jump to grandparent commit |
| `q` | Close blame |

> For a quick inline summary of who last touched the current line,
> use the custom `:Blame` command (`plugin/git_helpers.vim`).

---

## Log

| Command | Action |
|---------|--------|
| `:Git log` | Full repo log |
| `:Git log %` | Log for the current file only |
| `:Gclog` | Load file log into the quickfix list |

Press `<Enter>` on any commit in the log to open it.

---

## Reading and writing

| Command | Action |
|---------|--------|
| `:Gwrite` | Stage current file (equivalent to `git add %`) |
| `:Gread` | Revert current file to index (equivalent to `git checkout %`) |

---

## Lazy-loading note

Fugitive and vim-rhubarb are loaded together the first time any of these commands is used:

```
:Git  :G  :Gblame  :Glog  :Gclog  :Gdiffsplit  :Gvdiffsplit  :GBrowse  …
```
