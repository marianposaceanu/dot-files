# vim-commentary

Comment and uncomment code with a single motion. Works with any filetype that has a `commentstring` set.

---

## Comment a line (`gcc`)

```
gcc    toggle comment on current line
```

---

## Comment a motion (`gc`)

```
gc{motion}
```

| Keypress | Action |
|----------|--------|
| `gcj` | Comment current line + line below |
| `gcap` | Comment around paragraph |
| `gc3j` | Comment current line + 3 lines below |
| `gci{` | Comment everything inside `{...}` |
| `gcG` | Comment from current line to end of file |

---

## Visual mode

Select lines visually, then press `gc`:

```
V + select lines + gc    →   toggles comments on all selected lines
```

---

## How comments are formatted

Uses the filetype's `commentstring`. Examples:

| Filetype | Comment style |
|----------|--------------|
| Ruby | `# code` |
| JavaScript | `// code` |
| HTML | `<!-- code -->` |
| Vim | `" code` |
| Python | `# code` |
| SQL | `-- code` |

No configuration needed — it picks up the right style automatically.

---

## Works with vim-repeat

Pressing `.` after a `gc` operation repeats the same comment toggle on the same number of lines.
