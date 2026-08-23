#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
EXPECTED_REPO="$HOME/dot-files"
GHOSTTY_APP_PATH="${GHOSTTY_APP_PATH:-/Applications/Ghostty.app}"
OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
SKIP_CHECKS=0
TIMINGS=0
OH_MY_ZSH_TMP=''
PROGRESS_MODE='plain'
PROGRESS_ACTIVE=0
PROGRESS_VISIBLE=0
PROGRESS_PERCENT=0
PROGRESS_LINES=0
PROGRESS_COLUMNS=0
PROGRESS_TEXT=''
PROGRESS_BAR_ROW=-1
PROGRESS_RESIZE_COUNT=0
DETECTED_LINES=0
DETECTED_COLUMNS=0
TIMING_NAMES=()
TIMING_DURATIONS_MS=()
TIMING_NAME=''
TIMING_STARTED_MS=0
STAGE_INDEX=0
STAGE_TOTAL=9
BOLD=''
CYAN=''
GREEN=''
YELLOW=''
RED=''
RESET=''

if [ -t 1 ] && [ "${TERM:-}" != 'dumb' ]; then
  if [ -z "${NO_COLOR:-}" ]; then
    BOLD="$(printf '\033[1m')"
    CYAN="$(printf '\033[36m')"
    GREEN="$(printf '\033[32m')"
    YELLOW="$(printf '\033[33m')"
    RED="$(printf '\033[31m')"
    RESET="$(printf '\033[0m')"
  fi
  if tput csr 0 1 >/dev/null 2>&1 \
    && tput cup 0 0 >/dev/null 2>&1 \
    && tput sc >/dev/null 2>&1 \
    && tput rc >/dev/null 2>&1 \
    && tput el >/dev/null 2>&1; then
    PROGRESS_MODE='reserved'
  else
    PROGRESS_MODE='inline'
  fi
fi

usage() {
  cat <<'EOF'
Usage: ./bootstrap/legacy/install_macos.sh [--skip-checks] [--timings]

Install the macOS tools used by this repository, install mextdisplay, initialize
Vim submodules, and link the managed configuration files into $HOME. Existing
destinations are preserved with timestamped backups by
bootstrap/legacy/setup/link_configs.sh.

Options:
  --skip-checks  Skip the final config and environment validation.
  --timings      Print elapsed time for each installation stage.
  -h, --help     Show this help.
EOF
}

die() {
  clear_progress
  printf '%s✗%s %sError:%s %s\n' "$RED" "$RESET" "$BOLD" "$RESET" "$1" >&2
  exit 1
}

success() {
  clear_progress
  printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$1"
}

info() {
  clear_progress
  printf '  %s•%s %s\n' "$CYAN" "$RESET" "$1"
}

warning() {
  clear_progress
  printf '  %s!%s %s\n' "$YELLOW" "$RESET" "$1"
}

print_banner() {
  local validation='enabled'

  if [ "$SKIP_CHECKS" -eq 1 ]; then
    validation='skipped by request'
  fi
  printf '\n%s╭─ DOT-FILES :: MACOS SETUP%s\n' "${BOLD}${CYAN}" "$RESET"
  printf '│  %-12s %s\n' 'Repository' "$REPO_ROOT"
  printf '│  %-12s %s\n' 'Validation' "$validation"
  printf '╰─ Safe to rerun; existing files are backed up before linking.\n'
}

print_completion() {
  local validation='passed'

  if [ "$SKIP_CHECKS" -eq 1 ]; then
    validation='skipped'
  fi
  printf '\n%s╭─ SETUP COMPLETE%s\n' "${BOLD}${GREEN}" "$RESET"
  printf '│  %-12s %s\n' 'Repository' "$EXPECTED_REPO"
  printf '│  %-12s %s\n' 'Configs' 'managed links ready'
  printf '│  %-12s %s\n' 'Validation' "$validation"
  printf '╰─ Next: restart the terminal or run source ~/.zshrc\n'
}

monotonic_milliseconds() {
  /usr/bin/perl -MTime::HiRes=clock_gettime,CLOCK_MONOTONIC \
    -e 'printf "%.0f\n", clock_gettime(CLOCK_MONOTONIC) * 1000'
}

start_timing() {
  if [ "$TIMINGS" -ne 1 ]; then
    return 0
  fi
  TIMING_NAME="$1"
  TIMING_STARTED_MS="$(monotonic_milliseconds)"
}

finish_timing() {
  local finished_ms duration_ms

  if [ "$TIMINGS" -ne 1 ]; then
    return 0
  fi
  finished_ms="$(monotonic_milliseconds)"
  duration_ms=$((finished_ms - TIMING_STARTED_MS))
  TIMING_NAMES+=("$TIMING_NAME")
  TIMING_DURATIONS_MS+=("$duration_ms")
}

print_timing_report() {
  local index duration_ms share_tenths total_ms=0

  if [ "$TIMINGS" -ne 1 ]; then
    return 0
  fi
  printf '\n%s╭─ STAGE TIMINGS%s\n' "${BOLD}${CYAN}" "$RESET"
  for duration_ms in "${TIMING_DURATIONS_MS[@]}"; do
    total_ms=$((total_ms + duration_ms))
  done
  for ((index = 0; index < ${#TIMING_NAMES[@]}; index++)); do
    duration_ms="${TIMING_DURATIONS_MS[$index]}"
    share_tenths=$((duration_ms * 1000 / total_ms))
    printf '│  %-34s %3d.%03ds  %3d.%d%%\n' \
      "${TIMING_NAMES[$index]}" \
      "$((duration_ms / 1000))" "$((duration_ms % 1000))" \
      "$((share_tenths / 10))" "$((share_tenths % 10))"
  done
  printf '╰─ %-34s %3d.%03ds  100.0%%\n' \
    'Total' "$((total_ms / 1000))" "$((total_ms % 1000))"
}

read_terminal_size() {
  local size rows columns

  size="$(stty size </dev/tty 2>/dev/null || true)"
  set -- $size
  rows="${1:-}"
  columns="${2:-}"

  case "$rows" in ''|*[!0-9]*) rows='' ;; esac
  case "$columns" in ''|*[!0-9]*) columns='' ;; esac

  if [ -z "$rows" ] || [ "$rows" -le 0 ]; then
    rows="$(tput lines 2>/dev/null || true)"
  fi
  if [ -z "$columns" ] || [ "$columns" -le 0 ]; then
    columns="$(tput cols 2>/dev/null || true)"
  fi

  case "$rows" in ''|*[!0-9]*) return 1 ;; esac
  case "$columns" in ''|*[!0-9]*) return 1 ;; esac
  [ "$rows" -gt 0 ] && [ "$columns" -gt 0 ] || return 1

  DETECTED_LINES="$rows"
  DETECTED_COLUMNS="$columns"
}

build_progress_text() {
  local bar_width filled empty filled_bar empty_bar

  if [ "$PROGRESS_COLUMNS" -ge 5 ] && [ "$PROGRESS_COLUMNS" -lt 16 ]; then
    printf -v PROGRESS_TEXT '%3d%%' "$PROGRESS_PERCENT"
    return
  elif [ "$PROGRESS_COLUMNS" -ge 2 ] && [ "$PROGRESS_COLUMNS" -lt 5 ]; then
    printf -v PROGRESS_TEXT '%d' "$PROGRESS_PERCENT"
    PROGRESS_TEXT="${PROGRESS_TEXT:0:$((PROGRESS_COLUMNS - 1))}"
    return
  elif [ "$PROGRESS_COLUMNS" -lt 2 ]; then
    PROGRESS_TEXT=''
    return
  fi

  # Leave the final terminal column unused to avoid automatic line wrapping.
  bar_width=$((PROGRESS_COLUMNS - 8))
  filled=$((PROGRESS_PERCENT * bar_width / 100))
  empty=$((bar_width - filled))
  printf -v filled_bar '%*s' "$filled" ''
  printf -v empty_bar '%*s' "$empty" ''
  filled_bar="${filled_bar// /#}"
  printf -v PROGRESS_TEXT '[%s%s] %3d%%' \
    "$filled_bar" "$empty_bar" "$PROGRESS_PERCENT"
}

restore_progress_terminal() {
  local old_bar_row current_last_line
  local save_cursor restore_cursor clear_line clear_old clear_current full_region
  local sequence

  [ "$PROGRESS_ACTIVE" -eq 1 ] || return
  old_bar_row="$PROGRESS_BAR_ROW"
  current_last_line=$((PROGRESS_LINES - 1))
  if read_terminal_size; then
    current_last_line=$((DETECTED_LINES - 1))
  fi

  save_cursor="$(tput sc 2>/dev/null || true)"
  restore_cursor="$(tput rc 2>/dev/null || true)"
  clear_line="$(tput el 2>/dev/null || true)"
  clear_old=''
  clear_current=''
  if [ "$old_bar_row" -ge 0 ] && [ "$old_bar_row" -le "$current_last_line" ]; then
    clear_old="$(tput cup "$old_bar_row" 0 2>/dev/null || true)$clear_line"
  fi
  if [ "$current_last_line" -ne "$old_bar_row" ]; then
    clear_current="$(tput cup "$current_last_line" 0 2>/dev/null || true)$clear_line"
  fi
  full_region="$(tput csr 0 "$current_last_line" 2>/dev/null || true)"

  # terminfo leaves the cursor undefined after csr, so save and restore it.
  sequence="${save_cursor}${clear_old}${clear_current}${restore_cursor}"
  sequence="${sequence}${save_cursor}${full_region}${restore_cursor}"
  printf '%s' "$sequence"
  PROGRESS_ACTIVE=0
  PROGRESS_BAR_ROW=-1
}

activate_progress_terminal() {
  local scroll_bottom
  local scroll_region output_position

  PROGRESS_LINES="$DETECTED_LINES"
  PROGRESS_COLUMNS="$DETECTED_COLUMNS"
  [ "$PROGRESS_LINES" -ge 3 ] || return 1
  scroll_bottom=$((PROGRESS_LINES - 2))

  if ! scroll_region="$(tput csr 0 "$scroll_bottom" 2>/dev/null)" \
    || ! output_position="$(tput cup "$scroll_bottom" 0 2>/dev/null)"; then
    PROGRESS_MODE='inline'
    return 1
  fi

  # csr makes the cursor position undefined. Put output inside the region.
  printf '%s%s' "$scroll_region" "$output_position"
  PROGRESS_ACTIVE=1
}

refresh_progress_terminal() {
  if ! read_terminal_size; then
    return 1
  fi

  if [ "$PROGRESS_ACTIVE" -eq 1 ] \
    && { [ "$DETECTED_LINES" -ne "$PROGRESS_LINES" ] \
      || [ "$DETECTED_COLUMNS" -ne "$PROGRESS_COLUMNS" ]; }; then
    restore_progress_terminal
  fi

  if [ "$PROGRESS_ACTIVE" -eq 0 ]; then
    activate_progress_terminal || return 1
  fi
}

draw_reserved_progress() {
  local last_line
  local save_cursor bar_position clear_line restore_cursor

  last_line=$((PROGRESS_LINES - 1))
  build_progress_text
  save_cursor="$(tput sc 2>/dev/null || true)"
  bar_position="$(tput cup "$last_line" 0 2>/dev/null || true)"
  clear_line="$(tput el 2>/dev/null || true)"
  restore_cursor="$(tput rc 2>/dev/null || true)"
  printf '%s' "${save_cursor}${bar_position}${clear_line}${PROGRESS_TEXT}${restore_cursor}"
  PROGRESS_VISIBLE=1
  PROGRESS_BAR_ROW="$last_line"
}

clear_progress() {
  if [ "$PROGRESS_MODE" = 'inline' ] && [ "$PROGRESS_VISIBLE" -eq 1 ]; then
    printf '\r\033[2K'
    PROGRESS_VISIBLE=0
  fi
}

show_progress() {
  PROGRESS_PERCENT="$1"

  if [ "$PROGRESS_MODE" = 'plain' ]; then
    if [ "$PROGRESS_PERCENT" -eq 100 ]; then
      printf '[##################################################] 100%%\n'
    fi
    return
  fi

  if [ "$PROGRESS_MODE" = 'reserved' ]; then
    if refresh_progress_terminal; then
      draw_reserved_progress
      return
    fi
    PROGRESS_MODE='inline'
  fi

  if read_terminal_size; then
    PROGRESS_COLUMNS="$DETECTED_COLUMNS"
  else
    PROGRESS_COLUMNS=58
  fi
  build_progress_text
  clear_progress
  printf '%s' "$PROGRESS_TEXT"
  PROGRESS_VISIBLE=1
}

show_stage_progress() {
  if [ "$SKIP_CHECKS" -eq 1 ]; then
    show_progress "$2"
  else
    show_progress "$1"
  fi
}

finish_progress() {
  local final_text

  if [ "$PROGRESS_MODE" = 'reserved' ] && [ "$PROGRESS_ACTIVE" -eq 1 ]; then
    build_progress_text
    final_text="$PROGRESS_TEXT"
    restore_progress_terminal
    printf '%s\n' "$final_text"
    PROGRESS_VISIBLE=0
  elif [ "$PROGRESS_MODE" = 'inline' ] && [ "$PROGRESS_VISIBLE" -eq 1 ]; then
    printf '\n'
    PROGRESS_VISIBLE=0
  fi
}

handle_terminal_resize() {
  PROGRESS_RESIZE_COUNT=$((PROGRESS_RESIZE_COUNT + 1))
  if [ "$PROGRESS_MODE" = 'reserved' ] && [ "$PROGRESS_ACTIVE" -eq 1 ]; then
    restore_progress_terminal
    show_progress "$PROGRESS_PERCENT" || true
  fi
}

run_with_progress() {
  local child_pid child_status resize_count_before_wait

  if [ "$PROGRESS_MODE" != 'reserved' ] || [ "$PROGRESS_ACTIVE" -ne 1 ] \
    || [ ! -x /usr/bin/perl ]; then
    "$@"
    return
  fi

  # Bash makes asynchronous children ignore INT and QUIT. Reset them before
  # exec so Ctrl-C still stops Homebrew, Git, and their descendants normally.
  /usr/bin/perl -e '
    $SIG{INT} = "DEFAULT";
    $SIG{QUIT} = "DEFAULT";
    $SIG{TERM} = "DEFAULT";
    $SIG{HUP} = "DEFAULT";
    exec @ARGV or die "exec failed: $!\n";
  ' -- "$@" </dev/tty &
  child_pid=$!
  while :; do
    resize_count_before_wait="$PROGRESS_RESIZE_COUNT"
    if wait "$child_pid"; then
      child_status=0
    else
      child_status=$?
    fi

    if [ "$child_status" -gt 128 ] \
      && [ "$PROGRESS_RESIZE_COUNT" -ne "$resize_count_before_wait" ]; then
      # A trapped WINCH interrupts wait without returning the child's status.
      continue
    fi
    return "$child_status"
  done
}

section() {
  clear_progress
  STAGE_INDEX=$((STAGE_INDEX + 1))
  printf '\n%s[%02d/%02d]%s %s%s%s\n' \
    "${BOLD}${CYAN}" "$STAGE_INDEX" "$STAGE_TOTAL" "$RESET" \
    "$BOLD" "$1" "$RESET"
}

cleanup() {
  trap - WINCH
  if [ "$PROGRESS_ACTIVE" -eq 1 ]; then
    restore_progress_terminal
  elif [ "$PROGRESS_MODE" = 'inline' ] && [ "$PROGRESS_VISIBLE" -eq 1 ]; then
    printf '\n'
    PROGRESS_VISIBLE=0
  fi
  if [ -n "$OH_MY_ZSH_TMP" ] && { [ -e "$OH_MY_ZSH_TMP" ] || [ -L "$OH_MY_ZSH_TMP" ]; }; then
    rm -rf "$OH_MY_ZSH_TMP"
  fi
}
trap cleanup EXIT
trap handle_terminal_resize WINCH

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-checks)
      SKIP_CHECKS=1
      ;;
    --timings)
      TIMINGS=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "unknown option: $1"
      ;;
  esac
  shift
done

if [ "$(uname -s)" != 'Darwin' ]; then
  die 'this installer supports macOS only'
fi

print_banner

start_timing 'Apple Command Line Tools'
section 'Apple Command Line Tools'
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install >/dev/null 2>&1 || true
  die 'Command Line Tools installation was requested; finish it, then rerun this installer'
fi
success 'Apple Command Line Tools are available.'
finish_timing
show_stage_progress 1 1

start_timing 'Repository path'
section 'Repository path'
if [ -d "$EXPECTED_REPO" ]; then
  expected_real="$(cd "$EXPECTED_REPO" && pwd -P)"
  if [ "$expected_real" != "$REPO_ROOT" ]; then
    die "$EXPECTED_REPO points to $expected_real instead of $REPO_ROOT"
  fi
  success "Repository path is ready: $EXPECTED_REPO"
elif [ -e "$EXPECTED_REPO" ] || [ -L "$EXPECTED_REPO" ]; then
  die "$EXPECTED_REPO exists but is not this repository"
else
  ln -s "$REPO_ROOT" "$EXPECTED_REPO"
  success "Linked repository path: $EXPECTED_REPO -> $REPO_ROOT"
fi
finish_timing
show_stage_progress 2 2

find_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
  elif [ -x /opt/homebrew/bin/brew ]; then
    printf '/opt/homebrew/bin/brew\n'
  elif [ -x /usr/local/bin/brew ]; then
    printf '/usr/local/bin/brew\n'
  else
    printf '\n'
  fi
}

start_timing 'Homebrew'
section 'Homebrew'
BREW_BIN="$(find_brew)"
if [ -z "$BREW_BIN" ]; then
  command -v curl >/dev/null 2>&1 || die 'curl is required to install Homebrew'
  info 'Installing Homebrew...'
  run_with_progress /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  BREW_BIN="$(find_brew)"
  [ -n "$BREW_BIN" ] || die 'Homebrew installation completed but brew was not found'
else
  success "Homebrew is already installed: $BREW_BIN"
fi
eval "$("$BREW_BIN" shellenv)"
finish_timing
show_stage_progress 3 3

start_timing 'Command-line dependencies'
section 'Command-line dependencies'
run_with_progress "$REPO_ROOT/bootstrap/legacy/setup/install_brew_deps.sh"
MEXTDISPLAY_PREFIX="$("$BREW_BIN" --prefix mextdisplay)"
MEXTDISPLAY_BIN="$MEXTDISPLAY_PREFIX/bin/mextdisplay"
[ -x "$MEXTDISPLAY_BIN" ] || die "mextdisplay is missing from $MEXTDISPLAY_BIN"
RUBY_PREFIX="$("$BREW_BIN" --prefix ruby)"
[ -x "$RUBY_PREFIX/bin/ruby" ] || die "Homebrew Ruby is missing from $RUBY_PREFIX"
export PATH="$RUBY_PREFIX/bin:$PATH"
VIM_PREFIX="$("$BREW_BIN" --prefix vim)"
[ -x "$VIM_PREFIX/bin/vim" ] || die "Homebrew Vim is missing from $VIM_PREFIX"
success 'Verified mextdisplay, Ruby, and Vim executables.'
finish_timing
show_stage_progress 17 82

find_ghostty() {
  if command -v ghostty >/dev/null 2>&1; then
    command -v ghostty
  elif [ -x "$GHOSTTY_APP_PATH/Contents/MacOS/ghostty" ]; then
    printf '%s/Contents/MacOS/ghostty\n' "$GHOSTTY_APP_PATH"
  else
    printf '\n'
  fi
}

start_timing 'Ghostty'
section 'Ghostty'
GHOSTTY_BIN="$(find_ghostty)"
if [ -n "$GHOSTTY_BIN" ]; then
  info "Ghostty is already installed: $GHOSTTY_BIN"
elif "$BREW_BIN" list --cask ghostty >/dev/null 2>&1; then
  info 'Repairing the Homebrew Ghostty installation...'
  run_with_progress env HOMEBREW_NO_AUTO_UPDATE=1 \
    "$BREW_BIN" reinstall --cask ghostty
else
  info 'Installing Ghostty...'
  run_with_progress env HOMEBREW_NO_AUTO_UPDATE=1 \
    "$BREW_BIN" install --cask ghostty
fi
GHOSTTY_BIN="$(find_ghostty)"
[ -n "$GHOSTTY_BIN" ] || die "Ghostty was installed but its executable is missing from $GHOSTTY_APP_PATH"
success 'Ghostty is ready.'
finish_timing
show_stage_progress 18 83

start_timing 'Oh My Zsh'
section 'Oh My Zsh'
if [ -f "$OH_MY_ZSH_DIR/oh-my-zsh.sh" ]; then
  success "Oh My Zsh is already installed: $OH_MY_ZSH_DIR"
elif [ -e "$OH_MY_ZSH_DIR" ] || [ -L "$OH_MY_ZSH_DIR" ]; then
  die "$OH_MY_ZSH_DIR exists but is not a complete Oh My Zsh installation"
else
  mkdir -p "$(dirname "$OH_MY_ZSH_DIR")"
  oh_my_zsh_candidate="${OH_MY_ZSH_DIR}.install.$$"
  [ ! -e "$oh_my_zsh_candidate" ] && [ ! -L "$oh_my_zsh_candidate" ] \
    || die "temporary installation path already exists: $oh_my_zsh_candidate"
  OH_MY_ZSH_TMP="$oh_my_zsh_candidate"
  run_with_progress git clone --depth=1 \
    https://github.com/ohmyzsh/ohmyzsh.git "$OH_MY_ZSH_TMP"
  mv "$OH_MY_ZSH_TMP" "$OH_MY_ZSH_DIR"
  OH_MY_ZSH_TMP=''
  success "Oh My Zsh installed: $OH_MY_ZSH_DIR"
fi
finish_timing
show_stage_progress 19 84

start_timing 'Pinned Vim plugins'
section 'Pinned Vim plugins'
run_with_progress "$REPO_ROOT/bootstrap/legacy/submodules/update_submodules.sh" >/dev/null
success 'Pinned Vim plugins are ready.'
finish_timing
show_stage_progress 20 94

start_timing 'Configuration links'
section 'Configuration links'
link_summary="$("$REPO_ROOT/bootstrap/legacy/setup/link_configs.sh" --summary)"
success "Configuration links: $link_summary"
finish_timing
show_stage_progress 21 99

section 'Validation'
if [ "$SKIP_CHECKS" -eq 0 ]; then
  start_timing 'Repository checks'
  run_with_progress "$REPO_ROOT/bootstrap/legacy/checks/check_configs.sh"
  finish_timing
  show_progress 75
  start_timing 'Ghostty validation'
  "$GHOSTTY_BIN" +validate-config >/dev/null
  finish_timing
  show_progress 76
  start_timing 'Environment doctor'
  run_with_progress "$REPO_ROOT/bootstrap/legacy/checks/doctor.sh"
  finish_timing
  success 'Repository, Ghostty, and environment checks passed.'
else
  warning 'Final checks were skipped. Run these when ready:'
  printf '    %s/bootstrap/legacy/checks/check_configs.sh\n' "$REPO_ROOT"
  printf '    %s/bootstrap/legacy/checks/doctor.sh\n' "$REPO_ROOT"
fi

print_timing_report
show_progress 100
finish_progress
print_completion
