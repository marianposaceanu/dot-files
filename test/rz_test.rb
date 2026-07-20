#!/usr/bin/env ruby

require "minitest/autorun"
require "tmpdir"

load File.expand_path("../ghostty/scripts/rz", __dir__)

class RzTest < Minitest::Test
  class RecordingRz < Rz
    attr_reader :commands

    def initialize(argv)
      super
      @commands = []
    end

    private

    def run_command(*command)
      @commands << command
      return "1.3.1" if command.last.include?("get version")
      return "window-current" if command.last.include?("id of first window")

      header = %w[
        window_index window_id window_name window_x window_y window_width window_height
        tab_index tab_id tab_name tab_selected terminal_index terminal_id terminal_name
        terminal_focused working_directory scrollback_path
      ]
      row = [
        "2", "window-current", "Work", "100", "120", "1200", "800",
        "1", "tab-1", "Project", "true", "1", "terminal-1", "codex",
        "true", "/tmp/project", ""
      ]
      ([header.join("\t"), row.join("\t")] + [""]).join("\n")
    end
  end

  def setup
    @state_dir = Dir.mktmpdir("rz-test")
    @previous_state_dir = ENV["RZ_STATE_DIR"]
    ENV["RZ_STATE_DIR"] = @state_dir
    @rz = RecordingRz.new([])
  end

  def teardown
    ENV["RZ_STATE_DIR"] = @previous_state_dir
    FileUtils.remove_entry(@state_dir)
  end

  def test_save_arguments_support_fast_current_window_snapshots
    options = @rz.send(
      :parse_save_arguments,
      ["backup", "--no-scrollback", "--current-window"]
    )

    assert_equal "backup", options.fetch(:name)
    refute options.fetch(:capture_scrollback)
    assert options.fetch(:current_window)
    assert_nil options.fetch(:window_id)
  end

  def test_save_arguments_reject_two_window_selectors
    error = assert_raises(RuntimeError) do
      @rz.send(
        :parse_save_arguments,
        ["backup", "--current-window", "--window-id", "window-1"]
      )
    end

    assert_match(/either --current-window or --window-id/, error.message)
  end

  def test_watcher_defaults_to_the_current_window
    options = @rz.send(:parse_watch_arguments, ["backup", "--every", "15m"])

    assert_equal "backup", options.fetch(:name)
    assert_equal 900, options.fetch(:interval_seconds)
    assert_equal "current-window", options.fetch(:scope)
  end

  def test_watcher_can_explicitly_cover_all_windows
    options = @rz.send(
      :parse_watch_arguments,
      ["backup", "--every", "1h", "--all-windows"]
    )

    assert_equal 3600, options.fetch(:interval_seconds)
    assert_equal "all-windows", options.fetch(:scope)
  end

  def test_watcher_rejects_an_aggressive_interval
    error = assert_raises(RuntimeError) do
      @rz.send(:parse_watch_arguments, ["backup", "--every", "5s"])
    end

    assert_match(/at least 10 seconds/, error.message)
  end

  def test_capture_passes_the_bound_window_id_to_applescript
    rows = @rz.send(
      :capture_ghostty,
      capture_scrollback: false,
      window_id: "window-current"
    )

    command = @rz.commands.last
    assert_includes command, "--no-scrollback"
    assert_equal ["--window-id", "window-current"], command.last(2)
    assert_equal 1, rows.length
    assert_equal "window-current", rows.first.fetch("window_id")
    assert_equal 2, rows.first.fetch("window_index")
  end

  def test_snapshot_records_its_window_scope
    rows = @rz.send(
      :capture_ghostty,
      capture_scrollback: false,
      window_id: "window-current"
    )
    snapshot = @rz.send(
      :build_snapshot,
      "backup",
      "backup_20260720-120000",
      "20260720-120000",
      rows,
      [],
      [],
      capture_scrollback: false,
      target_window_id: "window-current"
    )

    assert_equal(
      {"type" => "window", "window_id" => "window-current"},
      snapshot.fetch("scope")
    )
    assert_equal 1, snapshot.fetch("windows").length
    assert_equal 1, snapshot.fetch("terminals_count")
  end

  def test_current_window_id_uses_ghosttys_front_window
    assert_equal "window-current", @rz.send(:current_ghostty_window_id)
    assert_includes @rz.commands.last, "-e"
    assert_includes @rz.commands.last.last, "id of first window"
  end
end
