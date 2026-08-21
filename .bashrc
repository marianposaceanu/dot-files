alias snow='sudo shutdown -h now'

# Keep the familiar command name while using the faster native search tool.
if command -v rg >/dev/null 2>&1; then
  alias ack=rg
fi
