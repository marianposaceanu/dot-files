# vim-endwise

Automatically adds closing keywords after you press `<Enter>` in insert mode. Works for Ruby, Bash, Vim script, Lua, Elixir, and more.

---

## How it works

Type an opening keyword and press `<Enter>` — vim-endwise appends the matching closer and positions the cursor in between.

### Ruby

```ruby
def greet        →  <Enter>  →   def greet
                                   |          (cursor here)
                                 end
```

```ruby
if condition     →  <Enter>  →   if condition
                                   |
                                 end
```

```ruby
do               →  <Enter>  →   do
                                   |
                                 end
```

### Bash / Zsh

```sh
if [ ... ]; then    →  <Enter>  →   if [ ... ]; then
                                       |
                                     fi
```

```sh
for i in ...; do    →  <Enter>  →   for i in ...; do
                                       |
                                     done
```

### Vim script

```vim
function! Foo()    →  <Enter>  →   function! Foo()
                                     |
                                   endfunction
```

---

## No configuration needed

vim-endwise detects the filetype automatically and applies the right closer. It does nothing in filetypes it doesn't recognise.
