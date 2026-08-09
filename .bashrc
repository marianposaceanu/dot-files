alias snow='sudo shutdown -h now'

# Keep the familiar command name while using the faster native search tool.
if command -v rg >/dev/null 2>&1; then
  alias ack=rg
fi

# Save and restore named Ghostty workspaces.
unalias rz 2>/dev/null
rz() {
  "$HOME/dot-files/ghostty/scripts/rz" "$@"
}
