# vim-surround

Add, change, or delete surrounding characters — quotes, brackets, tags — with single keypresses.

---

## Add a surrounding (`ys`)

```
ys{motion}{char}
```

| Keypress | Before | After |
|----------|--------|-------|
| `ysiw"` | `hello` | `"hello"` |
| `ysiw'` | `hello` | `'hello'` |
| `ysiw(` | `hello` | `( hello )` |
| `ysiw)` | `hello` | `(hello)` |
| `ysiw[` | `hello` | `[ hello ]` |
| `ysiw]` | `hello` | `[hello]` |
| `ysiw{` | `hello` | `{ hello }` |
| `ysiw}` | `hello` | `{hello}` |
| `ysiwt` | `hello` | prompts for a tag, e.g. `<em>hello</em>` |

> Opening bracket adds spaces; closing bracket does not.

### Surround a whole line

```
yss"    →   surrounds the entire line (ignoring indent)
```

---

## Change a surrounding (`cs`)

```
cs{old}{new}
```

| Keypress | Before | After |
|----------|--------|-------|
| `cs"'` | `"hello"` | `'hello'` |
| `cs'(` | `'hello'` | `( hello )` |
| `cs[{` | `[hello]` | `{hello}` |
| `cst"` | `<em>hello</em>` | `"hello"` |
| `cs"t` | `"hello"` | prompts for a tag |

---

## Delete a surrounding (`ds`)

```
ds{char}
```

| Keypress | Before | After |
|----------|--------|-------|
| `ds"` | `"hello"` | `hello` |
| `ds(` | `( hello )` | `hello` |
| `dst` | `<em>hello</em>` | `hello` |

---

## Visual mode (`S`)

Select text visually, then press `S{char}`:

```
v + select + S"    →   wraps selection in double quotes
v + select + St    →   wraps selection in an HTML tag
```

---

## Common patterns

| Task | Keys |
|------|------|
| Wrap word in double quotes | `ysiw"` |
| Wrap word in backticks | `ysiw` followed by a backtick |
| Remove quotes from string | `ds"` |
| Switch single to double quotes | `cs'"` |
| Wrap line in parentheses | `yss)` |
| Wrap selection in a tag | `VS<div>` |
