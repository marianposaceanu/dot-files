require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "open3"

class EditorConfigTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def setup
    @tmp = Dir.mktmpdir("dot-files-editor-")
    @env = { "XDG_STATE_HOME" => File.join(@tmp, "state"), "FZF_DEFAULT_COMMAND" => "",
             "FZF_DEFAULT_OPTS" => "--bind=ctrl-u:half-page-up" }
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def vim(commands)
    script = File.join(@tmp, "check.vim")
    errors = File.join(@tmp, "errors")
    File.write(script, <<~VIM)
      source #{ROOT}/.vim/plugin/git_helpers.vim
      #{commands}
      call writefile(v:errors, '#{errors}')
      if !empty(v:errors) | cquit | endif
      qa!
    VIM
    output, status = Open3.capture2e(@env, "vim", "-Nu", "#{ROOT}/.vimrc", "-i", "NONE", "-es", "-S", script, chdir: @tmp)
    assert status.success?, "#{output}\n#{File.read(errors) if File.exist?(errors)}"
  end

  def git(*args)
    output, status = Open3.capture2e("git", "-C", @tmp, *args)
    assert status.success?, output
    output.strip
  end

  def test_git_helpers_report_failures_without_commit_links
    File.write(File.join(@tmp, "file.txt"), "hello\n")
    vim <<~VIM
      edit #{@tmp}/file.txt
      let output = execute('Blame')
      call assert_match('not a git repository', output)
      call assert_notmatch('Commit:', output)
      let output = execute('LogSearch')
      call assert_match('not a git repository', output)
      call assert_notmatch('Commit:', output)
    VIM
  end

  def test_git_helpers_use_file_directory_and_visual_line_range
    git("init", "-q")
    git("config", "user.name", "Config Test")
    git("config", "user.email", "test@example.invalid")
    git("remote", "add", "origin", "git@github.com:example/test.git")
    file = File.join(@tmp, "file with spaces.txt")
    File.write(file, "alpha\nmiddle\nomega\n")
    git("add", ".")
    git("commit", "-qm", "Initial lines")
    first = git("rev-parse", "HEAD")
    File.write(file, "alpha\nomega\n")
    git("commit", "-qam", "Join lines")
    second = git("rev-parse", "HEAD")
    vim <<~VIM
      execute 'edit ' . fnameescape('#{file}')
      cd /
      let output = execute('Blame')
      call assert_match('/commit/#{first}', output)
      let output = execute('1,2LogSearch')
      call assert_match('/commit/#{second}', output)
      call assert_notmatch('/commit/#{first}', output)
      redir => selected
      call feedkeys("ggVj" . nr2char(92) . 'gs', 'xt')
      redir END
      call assert_match('/commit/#{second}', selected)
    VIM
  end

  def test_fzf_lists_files_outside_git_and_preserves_options
    File.write(File.join(@tmp, "visible.txt"), "hello\n")
    vim <<~VIM
      call assert_match('--bind=ctrl-u:half-page-up', $FZF_DEFAULT_OPTS)
      call assert_match('--reverse', $FZF_DEFAULT_OPTS)
      let files = system($FZF_DEFAULT_COMMAND)
      call assert_equal(0, v:shell_error)
      call assert_match('visible.txt', files)
    VIM
  end

  def test_large_file_cursorline_stays_off_and_recovery_files_are_created
    File.write(File.join(@tmp, "large.txt"), "line\n" * 220_000)
    File.write(File.join(@tmp, "small.txt"), "before\n")
    vim <<~VIM
      edit #{@tmp}/large.txt
      call assert_equal(0, &l:cursorline)
      split #{@tmp}/small.txt
      call assert_equal(1, &l:cursorline)
      call assert_equal(1, &l:swapfile)
      call assert_equal(1, &writebackup)
      call assert_equal(1, &l:undofile)
      call assert_match('/state/vim/swap/', swapname('%'))
      call setline(1, 'after')
      write
      call assert_true(filereadable(undofile(expand('%:p'))))
      wincmd p
      call assert_equal(0, &l:cursorline)
    VIM
  end

  def test_bat_redirects_plain_contents
    file = File.join(@tmp, "sample.rb")
    contents = "puts 'hello'\n"
    File.write(file, contents)
    output, status = Open3.capture2e({ "BAT_CONFIG_PATH" => "#{ROOT}/bat/config" }, "bat", file)
    assert status.success?, output
    assert_equal contents, output
  end
end
