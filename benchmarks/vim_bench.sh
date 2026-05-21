#!/usr/bin/env bash
# benchmarks/vim_bench.sh
#
# A/B benchmark: Homebrew bottle vim vs native Apple-M4 optimised build.
#
# The Homebrew bottle is compiled with -Os -march=armv8-a (generic ARM).
# The native build uses -O3 -mcpu=apple-m4 -ffp-contract=fast -flto.
# This script installs each in turn, runs the same workloads, and compares.
#
# Workloads are CPU-bound operations that benefit from -O3 / LTO:
#
#   regex_scan      NFA scan over 100k lines, count only (no substitution)
#   regex_replace   NFA scan + substitution over 100k lines
#   sort            Buffer sort of 100k lines
#   vimscript_loop  500k-iteration while loop (LTO inlines hot interpreter paths)
#   syntax_ruby     Force full syntax re-parse of a 4k-line Ruby file
#                   Ruby syntax chosen for complexity: heredocs, interpolation,
#                   regex literals, symbols, blocks, method chains — many more
#                   NFA states than C, puts more pressure on syntax.c.
#
# Usage:
#   ./benchmarks/vim_bench.sh
#       Full A/B run: bottle → bench → native → bench → compare
#
#   ./benchmarks/vim_bench.sh --bench-only [--label LABEL]
#       Benchmark the current vim only; save to results/LABEL_TIMESTAMP.txt
#
#   ./benchmarks/vim_bench.sh --compare BOTTLE_RESULT NATIVE_RESULT
#       Print comparison table for two previously saved result files
#
# Results are written to benchmarks/results/.
# Each benchmark runs RUNS=7 times; the median is reported.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$SCRIPT_DIR/results"
CORPUS_DIR="$SCRIPT_DIR/corpus"

RUNS=7
BENCH_ONLY=0
COMPARE_MODE=0
LABEL="bench"
COMPARE_BOTTLE=""
COMPARE_NATIVE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --bench-only)  BENCH_ONLY=1; shift ;;
    --label)       LABEL="$2"; shift 2 ;;
    --compare)     COMPARE_MODE=1; COMPARE_BOTTLE="$2"; COMPARE_NATIVE="$3"; shift 3 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 1 ;;
  esac
done

# ── Colours ───────────────────────────────────────────────────────────────────

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != "dumb" ]; then
  BOLD="$(printf '\033[1m')"
  GREEN="$(printf '\033[1;32m')"
  YELLOW="$(printf '\033[1;33m')"
  DIM="$(printf '\033[2m')"
  RESET="$(printf '\033[0m')"
else
  BOLD="" GREEN="" YELLOW="" DIM="" RESET=""
fi

info()    { printf '%s==>%s %s\n' "$BOLD"   "$RESET" "$1"; }
success() { printf '%s==>%s %s\n' "$GREEN"  "$RESET" "$1"; }
warn()    { printf '%s==>%s %s\n' "$YELLOW" "$RESET" "$1"; }

mkdir -p "$RESULTS_DIR" "$CORPUS_DIR"

# ── Corpus generation ─────────────────────────────────────────────────────────

WORDS_FILE="$CORPUS_DIR/words_100k.txt"
RUBY_FILE="$CORPUS_DIR/code_4k.rb"

generate_corpus() {
  if [ -f "$WORDS_FILE" ] && [ -f "$RUBY_FILE" ]; then return; fi
  info "Generating benchmark corpus (first run only) …"

  # 100k lines: random words 4–12 lowercase chars (fixed seed → reproducible)
  awk 'BEGIN {
    srand(31337)
    alpha = "abcdefghijklmnopqrstuvwxyz"
    for (i = 1; i <= 100000; i++) {
      n = 4 + int(rand() * 9)
      w = ""
      for (j = 1; j <= n; j++) w = w substr(alpha, int(rand()*26)+1, 1)
      print w
    }
  }' > "$WORDS_FILE"

  # ~4k line Ruby file stressing as many syntax features as possible:
  #   modules/classes, methods, blocks, string interpolation, heredocs,
  #   symbols, regex literals, method chains, DSL-style calls, comments.
  # The variety of patterns forces Vim's NFA engine to evaluate many syntax
  # rules per line, giving a realistic syntax.c workload.
  awk 'BEGIN {
    srand(42)
    split("process transform compute validate serialize filter reduce", verbs, " ")
    split("record item entry node payload response request config", nouns, " ")
    split("pending active completed failed queued retried skipped", states, " ")
    split("warn info debug error fatal", levels, " ")

    print "# frozen_string_literal: true"
    print ""
    print "require \"json\""
    print "require \"logger\""
    print "require \"ostruct\""
    print ""

    for (mod = 1; mod <= 8; mod++) {
      printf "module %s%d\n", (mod % 2 == 0 ? "Pipeline" : "Service"), mod
      printf "  TIMEOUT = %d\n", 30 + int(rand()*120)
      printf "  DEFAULT_RETRIES = %d\n", int(rand()*5)+1
      printf "  VERSION = \"%d.%d.%d\".freeze\n\n", int(rand()*3), int(rand()*9), int(rand()*9)

      for (cls = 1; cls <= 6; cls++) {
        noun = nouns[int(rand()*8)+1]
        printf "  class %s%dProcessor\n", toupper(substr(noun,1,1)) substr(noun,2), cls
        printf "    include Comparable\n"
        printf "    include Enumerable\n\n"
        printf "    attr_accessor :%s_id, :%s_state, :created_at\n", noun, noun
        printf "    attr_reader   :logger, :options\n\n"

        # initialize
        printf "    def initialize(%s_id, options = {})\n", noun
        printf "      @%s_id  = %s_id\n", noun, noun
        printf "      @options    = options.freeze\n"
        printf "      @logger     = Logger.new(\$stdout, level: :info)\n"
        printf "      @created_at = Time.now\n"
        printf "      @%s_state = :pending\n", noun
        printf "    end\n\n"

        for (meth = 1; meth <= 4; meth++) {
          verb = verbs[int(rand()*8)+1]
          level = levels[int(rand()*5)+1]
          state = states[int(rand()*7)+1]
          printf "    def %s_%s(input, timeout: TIMEOUT)\n", verb, noun
          printf "      logger.%s(\"Starting %s for #{%s_id} (state=#{%s_state})\")\n", level, verb, noun, noun
          printf "      raise ArgumentError, \"nil input for #{%s_id}\" if input.nil?\n", noun
          printf "\n"
          printf "      result = input\n"
          printf "        .reject { |item| item.nil? || item.empty? rescue false }\n"
          printf "        .map    { |item| item.to_s.strip.downcase }\n"
          printf "        .select { |item| item =~ /\\A[a-z][\\w\\-]{0,%d}\\z/ }\n", 30 + int(rand()*20)
          printf "        .uniq\n\n"
          printf "      @%s_state = :%s\n", noun, state
          printf "      logger.%s(\"Done: #{result.size} items processed in #{Time.now - @created_at}s\")\n", level
          printf "      result\n"
          printf "    rescue => e\n"
          printf "      logger.error(\"Failed in %s: #{e.class} — #{e.message}\")\n", verb
          printf "      raise\n"
          printf "    end\n\n"
        }

        # heredoc method
        printf "    def summary\n"
        printf "      <<~SUMMARY\n"
        printf "        ID:      #{%s_id}\n", noun
        printf "        State:   #{%s_state}\n", noun
        printf "        Created: #{created_at.strftime(\"%%Y-%%m-%%d %%H:%%M:%%S\")}\n"
        printf "        Options: #{options.inspect}\n"
        printf "      SUMMARY\n"
        printf "    end\n\n"

        # comparable
        printf "    def <=>(other)\n"
        printf "      [%s_state, created_at] <=> [other.%s_state, other.created_at]\n", noun, noun
        printf "    end\n\n"

        printf "  end\n\n"   # class
      }

      printf "end\n\n"   # module
    }

    # top-level DSL-style blocks
    print "# Configuration DSL"
    for (cfg = 1; cfg <= 20; cfg++) {
      printf "configure :%s do |c|\n", nouns[int(rand()*8)+1]
      printf "  c.timeout   = %d\n", 10 + int(rand()*100)
      printf "  c.retries   = %d\n", int(rand()*5)+1
      printf "  c.log_level = :%s\n", levels[int(rand()*5)+1]
      printf "  c.tags      = %%w[alpha beta gamma delta epsilon zeta].sample(%d)\n", int(rand()*4)+1
      printf "  c.on_error  { |e| warn \"[config-%d] #{e.message}\" }\n", cfg
      printf "end\n\n"
    }
  }' > "$RUBY_FILE"

  printf '%s  words_100k.txt: %d lines\n' "$DIM" "$(wc -l < "$WORDS_FILE")"
  printf   '  code_4k.rb:     %d lines%s\n' "$(wc -l < "$RUBY_FILE")" "$RESET"
}

# ── Benchmark runner ──────────────────────────────────────────────────────────
#
# Each benchmark:
#   1. Reloads the corpus from disk with :e! (not timed)
#   2. Times the workload block with reltime()
#   3. Repeats RUNS times; writes all timings to a temp file
# The bash side reads the temp file and returns the median.

BENCH_TMP="$(mktemp -d)"
trap 'rm -rf "$BENCH_TMP"' EXIT

run_bench() {
  local vim_bin="$1"
  local bench_name="$2"
  local corpus="$3"
  local timings_file="$BENCH_TMP/${bench_name}_timings.txt"
  local script_file="$BENCH_TMP/${bench_name}.vim"

  {
    printf 'let g:_times = []\n'
    printf 'let g:_i = 0\n'
    printf 'while g:_i < %d\n' "$RUNS"
    printf '  silent! e!\n'
    printf '  let g:_t = reltime()\n'

    case "$bench_name" in
      regex_scan)
        # Count all word matches — no substitution, pure NFA traversal
        printf '  silent! %%substitute/\w\+//gn\n'
        ;;
      regex_replace)
        # Wrap every 3–8 char word in brackets — NFA + substitution engine
        printf '  silent! %%substitute/\<\w\{3,8\}\>/[&]/g\n'
        ;;
      sort)
        printf '  silent! %%sort\n'
        ;;
      vimscript_loop)
        # Tight while loop: tests Vimscript interpreter dispatch + LTO inlining
        printf '  let g:_x = 0\n'
        printf '  let g:_j = 0\n'
        printf '  while g:_j < 500000\n'
        printf '    let g:_x += g:_j\n'
        printf '    let g:_j += 1\n'
        printf '  endwhile\n'
        ;;
      regex_ruby)
        # Complex alternation on 4k-line Ruby code — proxy for what the Ruby
        # syntax engine evaluates per line: keywords, symbols, quoted strings,
        # comments, and numbers.  Exercises NFA alternation + backtracking on
        # structured, realistic input rather than random word lists.
        # Note: true syntax highlighting requires a live display; in -Es batch
        # mode syntax state is computed lazily (only on redraw) so
        # 'syntax sync fromstart' is a no-op.  This regex covers the same
        # pattern space that syntax rules match.
        printf '  silent! %%substitute/\<\(def\|class\|module\|do\|end\|if\|unless\|rescue\)\>\|:\w\+\|"[^"]*"\|'"'"'[^'"'"']*'"'"'\|#.*$\|[0-9]\+//gn\n'
        ;;
    esac

    printf '  call add(g:_times, reltimefloat(reltime(g:_t)))\n'
    printf '  let g:_i += 1\n'
    printf 'endwhile\n'
    printf "call writefile(map(copy(g:_times), 'string(v:val)'), '%s')\n" "$timings_file"
    printf 'qa!\n'
  } > "$script_file"

  "$vim_bin" -Es "$corpus" -S "$script_file" </dev/null 2>/dev/null || true

  if [ ! -s "$timings_file" ]; then
    printf 'ERR'
    return
  fi

  # Sort numerically, return the median element
  sort -g "$timings_file" \
    | awk "NR==$(( (RUNS + 1) / 2 )){printf \"%.4f\", \$1}"
}

# ── Benchmark labels ───────────────────────────────────────────────────────────

bench_desc() {
  case "$1" in
    regex_scan)      printf 'Regex scan NFA        (100k lines, no subst)' ;;
    regex_replace)   printf 'Regex + replace NFA   (100k lines)'           ;;
    sort)            printf 'Buffer sort           (100k lines)'            ;;
    vimscript_loop)  printf 'Vimscript while loop  (500k iters)'           ;;
    regex_ruby)      printf 'Regex on Ruby code    (4k-line .rb, alts)'    ;;
  esac
}

bench_corpus() {
  case "$1" in
    syntax_ruby) printf '%s' "$RUBY_FILE"  ;;
    regex_ruby)  printf '%s' "$RUBY_FILE"  ;;
    *)           printf '%s' "$WORDS_FILE" ;;
  esac
}

BENCH_KEYS="regex_scan regex_replace sort vimscript_loop regex_ruby"

# ── Run all benchmarks for one vim binary ─────────────────────────────────────

run_all_benchmarks() {
  local vim_bin="$1"
  local result_file="$2"

  local compiled_by cflags
  compiled_by="$("$vim_bin" --version 2>/dev/null \
    | grep 'Compiled by' | sed 's/.*Compiled by //')"
  cflags="$(strings "$vim_bin" 2>/dev/null \
    | grep -E 'clang -c.*-O[0-9Os]' | head -1 || printf 'unknown')"

  {
    printf 'vim_binary:   %s\n' "$vim_bin"
    printf 'compiled_by:  %s\n' "$compiled_by"
    printf 'cflags:       %s\n' "$cflags"
    printf 'runs:         %d\n' "$RUNS"
    printf 'timestamp:    %s\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf '%s\n' '---'
  } > "$result_file"

  for bench in $BENCH_KEYS; do
    printf '  %-48s ' "$(bench_desc "$bench") …"
    local t
    t="$(run_bench "$vim_bin" "$bench" "$(bench_corpus "$bench")")"
    printf '%s s\n' "$t"
    printf '%s: %s\n' "$bench" "$t" >> "$result_file"
  done
}

# ── Install helpers ────────────────────────────────────────────────────────────

install_bottle() {
  info "Installing Homebrew bottle vim …"
  brew unpin vim 2>/dev/null || true
  brew reinstall vim
  hash -r 2>/dev/null || true
}

install_native() {
  info "Building native-apple-m4 optimised vim …"
  brew unpin vim 2>/dev/null || true
  bash "$ROOT_DIR/bootstrap/compile_vim_native.sh"
  hash -r 2>/dev/null || true
}

# ── Comparison table ───────────────────────────────────────────────────────────

print_comparison() {
  local bottle_file="$1"
  local native_file="$2"

  local b_by n_by b_cflags n_cflags b_ts n_ts
  b_by="$(grep '^compiled_by:' "$bottle_file" | cut -d' ' -f2-)"
  n_by="$(grep '^compiled_by:' "$native_file" | cut -d' ' -f2-)"
  b_cflags="$(grep '^cflags:' "$bottle_file" | cut -d' ' -f2-)"
  n_cflags="$(grep '^cflags:' "$native_file" | cut -d' ' -f2-)"
  b_ts="$(grep '^timestamp:' "$bottle_file" | cut -d' ' -f2-)"
  n_ts="$(grep '^timestamp:' "$native_file" | cut -d' ' -f2-)"

  printf '\n%s━━━ vim benchmark results ━━━%s\n' "$BOLD" "$RESET"
  printf '\n%sBOTTLE%s  compiled by: %s\n' "$DIM" "$RESET" "$b_by"
  printf '%s        recorded:    %s%s\n' "$DIM" "$b_ts" "$RESET"
  if [ "$b_cflags" != "unknown" ]; then
    printf '%s        cflags:      %s%s\n' "$DIM" "$b_cflags" "$RESET"
  fi
  printf '\n%sNATIVE%s  compiled by: %s\n' "$DIM" "$RESET" "$n_by"
  printf '%s        recorded:    %s%s\n' "$DIM" "$n_ts" "$RESET"
  if [ "$n_cflags" != "unknown" ]; then
    printf '%s        cflags:      %s%s\n' "$DIM" "$n_cflags" "$RESET"
  fi
  printf '\n%sMedian of %d runs. Green = native faster by >5%%. Yellow = native slower.%s\n\n' \
    "$DIM" "$RUNS" "$RESET"

  printf '%s%-48s  %10s  %10s  %8s%s\n' \
    "$BOLD" "Benchmark" "Bottle (s)" "Native (s)" "Speedup" "$RESET"
  printf '%s\n' \
    "────────────────────────────────────────────────────────────────────────────────"

  local any_error=0
  for bench in $BENCH_KEYS; do
    local b_t n_t
    b_t="$(grep "^${bench}:" "$bottle_file" | awk '{print $2}' || printf 'ERR')"
    n_t="$(grep "^${bench}:" "$native_file" | awk '{print $2}' || printf 'ERR')"

    if [ -z "$b_t" ] || [ -z "$n_t" ] || \
       [ "$b_t" = "ERR" ] || [ "$n_t" = "ERR" ]; then
      printf '%-48s  %10s  %10s  %8s\n' \
        "$(bench_desc "$bench")" "${b_t:-ERR}" "${n_t:-ERR}" "n/a"
      any_error=1
      continue
    fi

    local speedup color
    speedup="$(awk -v b="$b_t" -v n="$n_t" 'BEGIN{printf "%.2fx", b/n}')"
    if   awk -v b="$b_t" -v n="$n_t" 'BEGIN{exit (b/n >= 1.05) ? 0 : 1}'; then
      color="$GREEN"
    elif awk -v b="$b_t" -v n="$n_t" 'BEGIN{exit (b/n <= 0.95) ? 0 : 1}'; then
      color="$YELLOW"
    else
      color="$DIM"
    fi

    printf '%-48s  %10s  %10s  %s%8s%s\n' \
      "$(bench_desc "$bench")" "$b_t" "$n_t" "$color" "$speedup" "$RESET"
  done

  printf '%s\n' \
    "────────────────────────────────────────────────────────────────────────────────"
  printf '%sResults: %s%s\n' "$DIM" "$RESULTS_DIR" "$RESET"

  if [ "$any_error" -eq 1 ]; then
    warn "Some benchmarks errored. Check that -Es mode supports those commands."
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────

TS="$(date '+%Y%m%d_%H%M%S')"

if [ "$COMPARE_MODE" -eq 1 ]; then
  print_comparison "$COMPARE_BOTTLE" "$COMPARE_NATIVE"
  exit 0
fi

generate_corpus

if [ "$BENCH_ONLY" -eq 1 ]; then
  RESULT="$RESULTS_DIR/${LABEL}_${TS}.txt"
  VIM_BIN="$(command -v vim)"
  info "Benchmarking $(vim --version 2>/dev/null | head -1) …"
  run_all_benchmarks "$VIM_BIN" "$RESULT"
  success "Results: $RESULT"
  exit 0
fi

# ── Full A/B run ───────────────────────────────────────────────────────────────

BOTTLE_RESULT="$RESULTS_DIR/bottle_${TS}.txt"
NATIVE_RESULT="$RESULTS_DIR/native_${TS}.txt"

info "Step 1/4: Install Homebrew bottle"
install_bottle

info "Step 2/4: Benchmark bottle"
run_all_benchmarks "$(command -v vim)" "$BOTTLE_RESULT"
success "Bottle results: $(basename "$BOTTLE_RESULT")"

info "Step 3/4: Build native-apple-m4 vim (~90s)"
install_native

info "Step 4/4: Benchmark native"
run_all_benchmarks "$(command -v vim)" "$NATIVE_RESULT"
success "Native results: $(basename "$NATIVE_RESULT")"

print_comparison "$BOTTLE_RESULT" "$NATIVE_RESULT"
