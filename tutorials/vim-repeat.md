# vim-repeat

Makes the `.` repeat command work with plugin mappings, not just built-in Vim edits.

---

## What it fixes

Vim's `.` key repeats the last change. Without vim-repeat, plugin mappings (like those from vim-surround or vim-commentary) are not repeatable — `.` either does nothing or repeats only the last native edit.

With vim-repeat installed, those mappings register themselves properly and `.` works as expected.

---

## Examples

### With vim-surround

```
ysiw"    →   wrap word in quotes
.        →   wrap the next word in quotes too
```

### With vim-commentary

```
gcc      →   comment out a line
j.       →   move down, comment out that line too
```

---

## No configuration needed

vim-repeat has no commands or mappings of its own. It works automatically as long as it is loaded before the plugins it supports.

---

## Which plugins benefit

Any plugin that calls `repeat#set()` in its mappings. In this setup:

- vim-surround
- vim-commentary
- vim-unimpaired (if added later)
- vim-speeddating (if added later)
