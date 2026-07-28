# Initialize Homebrew for login shells when it is installed in either standard
# macOS prefix. Interactive setup in ~/.zshrc then refines PATH idempotently.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
