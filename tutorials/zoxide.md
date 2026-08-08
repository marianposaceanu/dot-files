---
published: 2026-08-08
visible-date: 8th August 2026
category: Shell tutorial
eyebrow: Zsh navigation · frecency · fzf
---
# zoxide: smarter directory jumping in Zsh

Zoxide learns the directories used most often and turns long paths into short, ranked keyword jumps. This setup keeps regular `cd` available and adds `z` for direct jumps plus `zi` for interactive selection.

---

## What this dot-files setup changes

The repository installs zoxide through Homebrew and initializes it at the end of `.zshrc`:

```sh
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi
```

Oh My Zsh has already initialized completions by this point, and all PATH changes are complete. The command guard lets Zsh start normally on a new machine before zoxide has been installed.

Zoxide's default `pwd` hook records directory changes. That means ordinary `cd` navigation teaches it too; there is no separate database-building step.

## Install and activate it

Install every command-line dependency declared by this repository:

```sh
./bootstrap/install_brew_deps.sh
```

Or install only zoxide and FZF:

```sh
brew install zoxide fzf
```

Reload the shell configuration, then confirm that zoxide generated the `z` and `zi` shell functions:

```sh
source ~/.zshrc
zoxide --version
type z
type zi
```

The first few jumps may need full paths or regular `cd` because the database starts empty. Navigation gets shorter as zoxide learns.

## Everyday jumps

| Command | Action |
|---------|--------|
| `z dot` | Jump to the highest-ranked directory matching `dot` |
| `z dot files` | Match multiple keywords in one query |
| `z ~/projects/example` | Use `z` like regular `cd` with a full path |
| `z example/` | Enter a relative directory |
| `z ..` | Move up one directory |
| `z -` | Return to the previous directory |
| `z foo /` | Enter a subdirectory whose name starts with `foo` |
| `zi dot` | Interactively choose among matching directories |

In Zsh, type a query followed by `Space` and `Tab` to see interactive completions:

```sh
z dot<Space><Tab>
```

## How matching learns your habits

Each visited directory receives a score. Repeated visits increase that score, while recent visits weigh more heavily than old ones. This combination of frequency and recency is often called **frecency**.

`z` filters the database by the supplied keywords and changes to the matching directory with the highest frecency. If a short query initially chooses the wrong place, use a more specific query or visit the preferred directory a few more times. Its ranking will adapt without a hand-maintained alias.

The database ages automatically. Low-scoring old entries eventually disappear as usage grows, so routine navigation does not require manual cleanup.

## Choose interactively with FZF

Use `zi` when a query has several useful matches:

```sh
zi projects
```

Zoxide sends the candidates to FZF. Type to narrow the list, use `Ctrl-J` and `Ctrl-K` to move, press `Enter` to jump, or press `Esc` to cancel. The repository's `FZF_DEFAULT_OPTS` also supplies Vim-style half-page movement with `Ctrl-D` and `Ctrl-U`.

FZF is optional for direct `z` jumps but required for `zi` and interactive completion. Zoxide currently requires FZF 0.51.0 or newer; the Homebrew formula in this repository satisfies that dependency.

## Inspect and maintain the database

List learned paths with their calculated scores:

```sh
zoxide query --list --score
```

Add or reinforce a path manually, or remove an unwanted entry:

```sh
zoxide add ~/projects/example
zoxide remove ~/projects/old-example
```

Removing a path does not permanently exclude it. If the directory is visited again, the default hook can add it back.

## Optional customization

Environment variables must be set before `zoxide init zsh`. For example, these settings print the selected destination and keep private project paths out of the database:

```sh
export _ZO_ECHO=1
export _ZO_EXCLUDE_DIRS="$HOME:$HOME/private/*"

eval "$(zoxide init zsh)"
```

The default exclusion already includes `$HOME` itself, but not its subdirectories. `_ZO_FZF_OPTS` can supply options only for zoxide's FZF picker, while the existing `FZF_DEFAULT_OPTS` continues to apply globally.

To use `j` and `ji` instead of `z` and `zi`, initialize with another command prefix:

```sh
eval "$(zoxide init zsh --cmd j)"
```

This repository intentionally keeps the standard `z` and `zi` names and does not replace `cd`.

## Troubleshooting

If `z` is not defined, first check `command -v zoxide`. The guarded setup skips initialization when the binary is absent, so install the formula and run `source ~/.zshrc` again.

If `zi` cannot open its picker, verify FZF with `fzf --version`. If Zsh completion does not appear after `Space` and `Tab`, rebuild the completion cache once:

```sh
rm ~/.zcompdump*
autoload -Uz compinit && compinit
source ~/.zshrc
```

See the [official zoxide repository](https://github.com/ajeetdsouza/zoxide) for platform-specific installers, import commands for older directory jumpers, and the complete configuration reference.
