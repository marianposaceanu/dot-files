# Non-interactive login shells skip ~/.zshrc, so load RVM here when needed.
# Interactive login shells already loaded it and are protected by the guard.
if (( ! $+functions[rvm] )) && [[ -s "$HOME/.rvm/scripts/rvm" ]]; then
  source "$HOME/.rvm/scripts/rvm"
fi
