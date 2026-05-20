# GoldenView.Vim

Automatically resizes Vim splits so the active window is larger than inactive ones — the "golden ratio" proportion. Lazy-loaded on first use.

---

## Toggle

```
<leader>gv    toggle GoldenView on / off
```

The first keypress loads the plugin and enables auto-resizing. A second press disables it and restores equal split sizes.

---

## What it does

When enabled, the active split takes up roughly 62% of the available space. Inactive splits share the rest. As you move between splits (`<C-h/j/k/l>`), the layout rebalances automatically.

This is useful when you have several splits open (e.g. file + fugitive diff + NERDTree) and want reading space in whichever one you're editing.

---

## Default mappings (provided by plugin)

GoldenView's own default mappings are disabled in this config:

```vim
let g:goldenview__enable_default_mapping = 0
```

Only the toggle is wired up via `<leader>gv`. This avoids conflicts with split-navigation keys.

---

## Tips

- Works best with 3+ splits open.
- Combine with `<C-h/j/k/l>` (wired in `.vimrc`) to navigate splits — the layout rebalances on every focus change.
- If you temporarily want equal splits, toggle GoldenView off, run `:wincmd =`, then toggle back on.
