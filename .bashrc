alias snow='sudo shutdown -h now'
alias sr='screen -r'

# Save and restore named Ghostty workspaces.
rz() {
  "$HOME/dot-files/ghostty/scripts/rz" "$@"
}
