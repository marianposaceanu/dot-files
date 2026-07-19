alias snow='sudo shutdown -h now'
alias sr='screen -r'

# Save and restore named Ghostty workspaces.
unalias rz 2>/dev/null
rz() {
  "$HOME/dot-files/ghostty/scripts/rz" "$@"
}
