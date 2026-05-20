# supertab

Tab completion in insert mode. Pressing `<Tab>` triggers completion using whatever completion method is currently active.

---

## Basic use

In insert mode, start typing and press `<Tab>`:

```
def lo<Tab>    →   completes to  def load_something   (if it's in scope)
```

Press `<Tab>` again to cycle through candidates. `<S-Tab>` cycles backwards.

---

## Completion context

Supertab detects the context and picks the right `completefunc` automatically:

| Context | Completion source |
|---------|------------------|
| After `.` or `::` | Omni-completion (`<C-x><C-o>`) |
| Inside a path (`/`) | File path completion |
| Elsewhere | Keyword completion from open buffers |

---

## Manual completion methods

If you want to force a specific completion type, use the standard Vim insert-mode shortcuts directly:

| Key | Completion type |
|-----|----------------|
| `<C-n>` / `<C-p>` | Keywords in open buffers |
| `<C-x><C-o>` | Omni-completion (language-aware) |
| `<C-x><C-f>` | File paths |
| `<C-x><C-l>` | Whole lines |
| `<C-x><C-]>` | Tags (requires ctags — `universal-ctags` is in the Brewfile) |

---

## With universal-ctags

Since `universal-ctags` is installed, tag-based completion is available. Generate tags for a project:

```sh
ctags -R .
```

Then `<C-x><C-]>` (or `<Tab>` after a known symbol) will complete against the tags file.
