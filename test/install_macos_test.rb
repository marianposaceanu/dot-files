#!/usr/bin/env ruby

require "fileutils"
require "minitest/autorun"
require "open3"
require "tmpdir"

class InstallMacosTest < Minitest::Test
  REPO_ROOT = File.expand_path("..", __dir__)
  INSTALLER = File.join(REPO_ROOT, "bootstrap/install_macos.sh")
  LEGACY_INSTALLER = File.join(REPO_ROOT, "bootstrap/legacy/install_macos.sh")
  BB_BIN = ENV["BB_BIN"] || ENV.fetch("PATH").split(File::PATH_SEPARATOR)
    .map { |directory| File.join(directory, "bb") }
    .find { |path| File.executable?(path) }
  raise "bb is required to run the installer tests" unless BB_BIN

  def setup
    @tmp_dir = Dir.mktmpdir("install-macos-test")
    @home = File.join(@tmp_dir, "home")
    @bin = File.join(@tmp_dir, "bin")
    @log = File.join(@tmp_dir, "commands.log")
    @brew_state = File.join(@tmp_dir, "brew-state")
    @clt_state = File.join(@tmp_dir, "clt-state")
    @ghostty_app = File.join(@home, "Applications/Ghostty.app")
    FileUtils.mkdir_p([@home, @bin])
    FileUtils.touch(@clt_state)
    File.write(File.join(@home, ".zshrc"), "original zsh config\n")
    write_stubs
  end

  def teardown
    FileUtils.remove_entry(@tmp_dir)
  end

  def test_two_runs_install_once_and_do_not_create_duplicate_backups
    brewfile = File.readlines(File.join(REPO_ROOT, "Brewfile"))
    assert_includes brewfile, "tap \"marianposaceanu/tap\"\n"
    assert_includes brewfile, "tap \"borkdude/brew\"\n"
    assert_includes brewfile, "brew \"babashka\"\n"
    assert_includes brewfile, "brew \"mextdisplay\"\n"
    assert_includes brewfile, "brew \"ruby\"\n"
    assert_includes brewfile, "brew \"vim\"\n"

    first_output = run_installer

    assert_includes first_output, "╭─ DOT-FILES :: MACOS SETUP"
    assert_includes first_output, "Linked repository path"
    assert_includes first_output, "╭─ SETUP COMPLETE"
    assert_includes first_output, "╰─ Next: restart the terminal or run source ~/.zshrc"
    assert_includes first_output, "[##################################################] 100%"
    refute_includes first_output, "\e"
    assert File.symlink?(File.join(@home, "dot-files"))
    assert_equal REPO_ROOT, File.realpath(File.join(@home, "dot-files"))
    assert_equal File.join(REPO_ROOT, ".zshrc"), File.realpath(File.join(@home, ".zshrc"))
    assert_equal File.join(REPO_ROOT, "codex/config.toml"), File.realpath(File.join(@home, ".codex/config.toml"))
    assert_equal File.join(REPO_ROOT, "amp/settings.json"), File.realpath(File.join(@home, ".config/amp/settings.json"))
    assert File.file?(File.join(@home, ".oh-my-zsh/oh-my-zsh.sh"))
    assert File.executable?(File.join(@tmp_dir, "homebrew/opt/mextdisplay/bin/mextdisplay"))
    assert File.executable?(File.join(@ghostty_app, "Contents/MacOS/ghostty"))

    backups = Dir.glob(File.join(@home, ".zshrc.backup.*"))
    assert_equal 1, backups.length
    assert_equal "original zsh config\n", File.read(backups.first)

    second_output = run_installer

    assert_includes second_output, "Repository path is ready"
    assert_includes second_output, "Ghostty is already installed"
    assert_includes second_output, "Oh My Zsh is already installed"
    assert_includes second_output, "[07/09] Pinned Vim plugins"
    assert_includes second_output, "✓ Pinned Vim plugins are ready."
    assert_includes second_output, "[08/09] Configuration links"
    assert_includes second_output, "✓ Configuration links: 13 unchanged, 0 updated, 0 backups."
    assert_includes second_output, "[09/09] Validation"
    refute_includes second_output, "Already linked:"
    assert_equal backups, Dir.glob(File.join(@home, ".zshrc.backup.*"))

    commands = File.readlines(@log, chomp: true)
    assert_equal 1, commands.count("brew install --cask ghostty")
    assert_equal 1, commands.count { |line| line.start_with?("git clone ") }
    assert_equal 2, commands.count("brew update")
    assert_equal 2, commands.count { |line| line.start_with?("brew bundle --file ") }
    assert_equal 2, commands.count("git submodule --quiet sync --recursive")
    assert_equal 2, commands.count("git submodule --quiet update --init --recursive")
  end

  def test_requests_command_line_tools_and_stops_for_their_installer
    FileUtils.rm_f(@clt_state)

    stdout, stderr, status = invoke_installer

    refute status.success?
    assert_empty stdout.scan("Ensuring Homebrew")
    assert_includes stderr, "Command Line Tools installation was requested"
    assert_includes File.readlines(@log, chomp: true), "xcode-select --install"
    refute File.exist?(File.join(@home, "dot-files"))
  end

  def test_repairs_a_ghostty_receipt_without_an_application
    FileUtils.touch(@brew_state)

    run_installer

    assert File.executable?(File.join(@ghostty_app, "Contents/MacOS/ghostty"))
    commands = File.readlines(@log, chomp: true)
    assert_equal 1, commands.count("brew reinstall --cask ghostty")
    assert_equal 0, commands.count("brew install --cask ghostty")
  end

  def test_optional_stage_timing_report
    output = run_installer(timings: true)

    assert_includes output, "╭─ STAGE TIMINGS"
    assert_match(/^│  Command-line dependencies +\d+\.\d{3}s +\d+\.\d%$/, output)
    assert_match(/^│  Pinned Vim plugins +\d+\.\d{3}s +\d+\.\d%$/, output)
    assert_match(/^╰─ Total +\d+\.\d{3}s +100\.0%$/, output)
  end

  def test_dependency_failure_is_reported_without_a_completion_panel
    stdout, stderr, status = invoke_installer(fail_brew: true)
    output = stdout + stderr

    refute status.success?
    assert_includes output, "simulated brew bundle failure"
    refute_includes output, "SETUP COMPLETE"
    assert_includes output, "✗ Error:"
  end

  def test_bootstrap_installs_babashka_when_the_binary_is_missing
    output = run_installer(include_bb: false)

    assert_includes output, "• Installing Babashka..."
    assert_includes output, "╭─ SETUP COMPLETE"
    assert_includes File.readlines(@log, chomp: true),
      "brew install borkdude/brew/babashka"
  end

  def test_legacy_installer_remains_runnable
    stdout, stderr, status = invoke_installer(installer: LEGACY_INSTALLER)

    assert status.success?, "legacy installer failed:\n#{stdout}\n#{stderr}"
    assert_includes stdout, "╭─ DOT-FILES :: MACOS SETUP"
    assert_includes stdout, "╭─ SETUP COMPLETE"
  end

  private

  def run_installer(interactive: false, timings: false, include_bb: true)
    stdout, stderr, status = invoke_installer(
      interactive: interactive,
      timings: timings,
      include_bb: include_bb
    )
    assert status.success?, "installer failed:\n#{stdout}\n#{stderr}"
    stdout
  end

  def invoke_installer(interactive: false, fail_brew: false, timings: false,
    include_bb: true, installer: INSTALLER)
    path = [@bin]
    path << File.dirname(BB_BIN) if include_bb
    path.concat(["/usr/bin", "/bin", "/usr/sbin", "/sbin"])
    env = {
      "HOME" => @home,
      "PATH" => path.join(":"),
      "INSTALLER_TEST_BB_BIN" => BB_BIN,
      "INSTALLER_TEST_LOG" => @log,
      "INSTALLER_TEST_BREW_STATE" => @brew_state,
      "INSTALLER_TEST_CLT_STATE" => @clt_state,
      "INSTALLER_TEST_RESIZE" => interactive ? "1" : "0",
      "INSTALLER_TEST_FAIL_BREW" => fail_brew ? "1" : "0",
      "GHOSTTY_APP_PATH" => @ghostty_app,
      "TERM" => "xterm-256color"
    }
    command = [installer, "--skip-checks"]
    command << "--timings" if timings
    if interactive
      command = [
        "/usr/bin/script", "-q", "/dev/null", "/bin/bash", "-c",
        'stty rows 24 cols 64; exec "$@"', "installer-progress-test", *command
      ]
    end
    Open3.capture3(env, *command)
  end

  def write_stubs
    write_executable("uname", <<~'SH')
      #!/usr/bin/env bash
      [ "${1:-}" = '-s' ] && printf 'Darwin\n' || /usr/bin/uname "$@"
    SH

    write_executable("xcode-select", <<~'SH')
      #!/usr/bin/env bash
      state="${INSTALLER_TEST_CLT_STATE:?}"
      if [ "${1:-}" = '-p' ]; then
        [ -f "$state" ] && { printf '/Library/Developer/CommandLineTools\n'; exit 0; }
        exit 1
      fi
      if [ "${1:-}" = '--install' ]; then
        printf 'xcode-select --install\n' >> "${INSTALLER_TEST_LOG:?}"
        exit 0
      fi
      exit 1
    SH

    write_executable("git", <<~'SH')
      #!/usr/bin/env bash
      log="${INSTALLER_TEST_LOG:?}"
      if [ "${1:-}" = 'clone' ]; then
        printf 'git %s\n' "$*" >> "$log"
        destination="${!#}"
        mkdir -p "$destination"
        touch "$destination/oh-my-zsh.sh"
        exit 0
      fi
      if [ "${1:-}" = '-C' ]; then
        shift 2
      fi
      printf 'git %s\n' "$*" >> "$log"
    SH

    write_executable("brew", <<~'SH')
      #!/usr/bin/env bash
      log="${INSTALLER_TEST_LOG:?}"
      state="${INSTALLER_TEST_BREW_STATE:?}"
      case "${1:-}" in
        shellenv)
          printf 'export HOMEBREW_PREFIX=%q\n' "$(dirname "$(dirname "$0")")"
          ;;
        --prefix)
          if [ -z "${2:-}" ]; then
            printf '%s/homebrew\n' "$(dirname "$state")"
            exit 0
          fi
          case "$2" in mextdisplay|ruby|vim) ;; *) exit 1 ;; esac
          prefix="$(dirname "$state")/homebrew/opt/$2"
          mkdir -p "$prefix/bin"
          touch "$prefix/bin/${2}"
          chmod +x "$prefix/bin/${2}"
          printf '%s\n' "$prefix"
          ;;
        update)
          printf 'brew update\n' >> "$log"
          if [ "${INSTALLER_TEST_RESIZE:-0}" = '1' ]; then
            stty rows 30 cols 100
            installer_pid="$(ps -o ppid= -p "$PPID" | tr -d ' ')"
            kill -WINCH "$installer_pid"
            sleep 0.2
            printf 'growth-child-still-running\n'
            stty rows 18 cols 48
            kill -WINCH "$installer_pid"
            sleep 0.2
            printf 'shrink-child-still-running\n'
          fi
          ;;
        bundle)
          if [ "${2:-}" = '--help' ]; then
            printf '%s\n' '--no-lock'
          elif [ "${INSTALLER_TEST_FAIL_BREW:-0}" = '1' ]; then
            printf 'simulated brew bundle failure\n' >&2
            exit 23
          else
            printf 'brew %s\n' "$*" >> "$log"
          fi
          ;;
        list)
          [ "${2:-}" = '--cask' ] && [ "${3:-}" = 'ghostty' ] && [ -f "$state" ]
          ;;
        install)
          printf 'brew %s\n' "$*" >> "$log"
          if [ "${2:-}" = 'borkdude/brew/babashka' ]; then
            ln -s "${INSTALLER_TEST_BB_BIN:?}" "$(dirname "$0")/bb"
            exit 0
          fi
          if [ "${2:-}" = '--cask' ] && [ "${3:-}" = 'ghostty' ]; then
            touch "$state"
            executable="${GHOSTTY_APP_PATH:?}/Contents/MacOS/ghostty"
            mkdir -p "$(dirname "$executable")"
            touch "$executable"
            chmod +x "$executable"
          fi
          ;;
        reinstall)
          printf 'brew %s\n' "$*" >> "$log"
          if [ "${2:-}" = '--cask' ] && [ "${3:-}" = 'ghostty' ]; then
            executable="${GHOSTTY_APP_PATH:?}/Contents/MacOS/ghostty"
            mkdir -p "$(dirname "$executable")"
            touch "$executable"
            chmod +x "$executable"
          fi
          ;;
        *)
          printf 'unexpected brew command: %s\n' "$*" >&2
          exit 1
          ;;
      esac
    SH
  end

  def write_executable(name, content)
    path = File.join(@bin, name)
    File.write(path, content)
    FileUtils.chmod(0o755, path)
  end
end
