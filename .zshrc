# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Plugins
plugins=(
  git
)

if [ -f "$ZSH/oh-my-zsh.sh" ]; then
  source "$ZSH/oh-my-zsh.sh"
else
  echo "[zshrc] Warning: oh-my-zsh not found at $ZSH" >&2
fi

# Locale
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Editor
export EDITOR="vim"
export VISUAL="vim"

# No Homebrew analytics
export HOMEBREW_NO_ANALYTICS=1

# JRuby dev mode (only when installed)
command -v jruby >/dev/null 2>&1 && export JRUBY_OPTS="--dev"

# Workaround for Ruby fork-safety issue on macOS (needed for Puma/Unicorn)
# See: https://github.com/puma/puma/issues/1421
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

# Java — prefer macOS resolver, fall back to known Homebrew ARM path
if command -v /usr/libexec/java_home >/dev/null 2>&1; then
  _java_home_candidate="$(/usr/libexec/java_home 2>/dev/null)"
  [ -n "$_java_home_candidate" ] && export JAVA_HOME="$_java_home_candidate"
  unset _java_home_candidate
elif [ -d "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home" ]; then
  export JAVA_HOME="/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home"
fi

# PATH — set once in priority order; typeset -U removes duplicates on nested shells
export PATH="$HOME/bin:/opt/homebrew/bin:/opt/homebrew/opt/curl/bin${JAVA_HOME:+:$JAVA_HOME/bin}:$PATH"
typeset -U PATH

# Save and restore named Ghostty workspaces.
unalias rz 2>/dev/null
rz() {
  "$HOME/dot-files/ghostty/scripts/rz" "$@"
}

# bat — cat replacement with syntax highlighting
if command -v bat >/dev/null 2>&1; then
  alias cat='bat'
  # Render man pages through bat
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# FZF — use bat for file previews when available
if command -v bat >/dev/null 2>&1; then
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --line-range :300 {}'"
  export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --bind 'ctrl-/:toggle-preview'"
fi
