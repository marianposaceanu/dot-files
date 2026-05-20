# tabular

Align text by a pattern. Lazy-loaded on first use of `:Tabularize`.

---

## Basic usage

```
:Tabularize /{pattern}
```

Select lines visually first (or let it detect the paragraph), then run the command.

---

## Common patterns

### Align by `=`

```ruby
# before
foo = 1
longer_name = 2
x = 3

# :Tabularize /=

foo         = 1
longer_name = 2
x           = 3
```

### Align by `=>`  (Ruby hashes)

```ruby
# before
{ foo: 1, bar: 2 }
{ foo: 'a', longer_key: 'b' }

# :Tabularize /=>

{ foo:        => 1 }
{ longer_key  => 'b' }
```

### Align by `,`

```
:Tabularize /,
```

### Align by `:`

```
:Tabularize /:\zs
```

`\zs` shifts the alignment point to after the `:`, keeping the colon attached to the left word.

### Align Markdown tables

```
:Tabularize /|
```

---

## Visual selection workflow

1. Visually select the lines to align (`V` + motion or `Shift-V` + mouse).
2. Run `:Tabularize /=>`

The selection is the most reliable way to scope alignment.

---

## Lazy-loading note

Tabular lives in `pack/bundles/opt/` and is loaded automatically the first time `:Tabularize` is invoked — no startup cost.
