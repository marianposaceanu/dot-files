# ==============================================================================
# CORE ENVIRONMENT
# ==============================================================================

# Use UTF-8 by default while leaving individual locale categories overridable.
export LANG=en_US.UTF-8

# Use Vim consistently for terminal programs that open an editor.
export EDITOR=vim
export VISUAL=vim

# Keep Homebrew commands quiet about analytics.
export HOMEBREW_NO_ANALYTICS=1

# Homebrew OpenJDK is keg-only, so expose its JDK home explicitly.
export JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home

# Add missing tool directories without reordering RVM's active Ruby on reload.
# Entries are listed from lowest to highest priority because each is prepended.
typeset -U path PATH
for _path_candidate in \
  "$JAVA_HOME/bin" \
  /opt/homebrew/opt/curl/bin \
  /opt/homebrew/sbin \
  /opt/homebrew/bin \
  "$HOME/bin"; do
  if [[ -d "$_path_candidate" && ":$PATH:" != *":$_path_candidate:"* ]]; then
    path=("$_path_candidate" "${path[@]}")
  fi
done
unset _path_candidate

# ==============================================================================
# INTERACTIVE SHELL
# ==============================================================================

# Load Oh My Zsh after the core environment so plugins see the final tool paths.
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=robbyrussell
plugins=(git)

if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  print -u2 -- "[zshrc] Warning: oh-my-zsh not found at $ZSH"
fi

# Save and restore named Ghostty workspaces through the repository-managed tool.
unalias rz 2>/dev/null
rz() {
  "$HOME/dot-files/ghostty/scripts/rz" "$@"
}

# Use bat as the interactive cat replacement and man-page renderer.
if (( $+commands[bat] )); then
  alias cat=bat
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# Keep the familiar command name while using the faster native search tool.
if (( $+commands[rg] )); then
  alias ack=rg
fi

# Load FZF completion and Ctrl-T directly from Homebrew.
if [[ -r /opt/homebrew/opt/fzf/shell/completion.zsh &&
      -r /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]]; then
  # Apple Silicon Homebrew.
  source /opt/homebrew/opt/fzf/shell/completion.zsh
  source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
elif [[ -r "$HOME/.fzf.zsh" ]]; then
  # Fallback for installations created by FZF's installer.
  source "$HOME/.fzf.zsh"
fi

# Use bat for Ctrl-T previews when available.
if (( $+commands[bat] )); then
  export FZF_CTRL_T_OPTS="--preview 'bat --color=always --line-range :300 {}'"
fi

# FZF provides Ctrl-J/Ctrl-K for line movement by default. Add Vim-style
# half-page movement and retain the preview toggle.
export FZF_DEFAULT_OPTS='--bind=ctrl-d:half-page-down,ctrl-u:half-page-up,ctrl-/:toggle-preview'

# Load RVM last because it intentionally selects the active Ruby by modifying
# PATH. Login shells that skip ~/.zshrc receive the same setup from ~/.zlogin.
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

# Initialize smarter directory jumps after compinit and all PATH changes.
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi
