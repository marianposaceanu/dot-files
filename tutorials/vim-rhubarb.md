# vim-rhubarb

GitHub extension for fugitive. Adds `:GBrowse` to open files, lines, and commits on github.com, and enables auto-completing GitHub issue/PR numbers in commit messages.

Both fugitive and rhubarb are lazy-loaded together on first use of any `:Git` command.

---

## Opening things on GitHub

### Current file

```
:GBrowse
```

Opens the current file on GitHub at the current branch/commit.

### Specific line or selection

```
:GBrowse          (normal mode — current line)
:'<,'>GBrowse     (visual mode — selected lines)
```

In visual mode, GitHub opens with the line range highlighted (e.g. `#L10-L25`).

### A specific commit

From fugitive's log (`:Git log`) or blame (`:Git blame`), place the cursor on a commit hash and run:

```
:GBrowse
```

Opens that commit's page on GitHub.

### A file from a specific commit or branch

```
:GBrowse main:path/to/file.rb
:GBrowse HEAD~3:path/to/file.rb
```

---

## Commit messages — issue/PR auto-complete

When writing a commit message (e.g. after `:Git commit`), type `#` in insert mode to trigger auto-complete for GitHub issues and PRs in the current repo:

```
Fixes #<Tab>   →   shows open issues to complete
```

Requires a GitHub token in the environment (`GITHUB_TOKEN`) or via the system keychain for private repos.

---

## How it relates to the custom :Blame helper

This repo also has a custom `:Blame` command (`plugin/git_helpers.vim`) that prints the commit URL for the current line. The two are complementary:

| Tool | What it does |
|------|-------------|
| `:Blame` (custom) | Prints hash + author + subject + URL inline in Vim |
| `:Git blame` (fugitive) | Opens an interactive blame split; navigate commits |
| `:GBrowse` (rhubarb) | Opens the file/line/commit directly in the browser |

---

## Lazy-loading note

Both `fugitive` and `vim-rhubarb` live in `pack/bundles/opt/` and are loaded together the first time any of these commands is used:

```
:Git  :G  :Gblame  :Glog  :Gdiffsplit  :GBrowse  …
```

There is no startup cost until you invoke one of them.
