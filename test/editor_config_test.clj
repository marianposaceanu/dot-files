(require '[babashka.classpath :as classpath]
         '[babashka.fs :as fs])
(classpath/add-classpath (-> *file* fs/canonicalize fs/parent fs/parent str))
(ns editor-config-test
  (:require [babashka.fs :as fs]
            [clojure.string :as str]
            [clojure.test :refer [deftest is use-fixtures]]
            [test.support :as support]))

(use-fixtures :each support/with-temp-dir)

(defn- vim! [commands]
  (let [script (support/path "check.vim")
        errors (support/path "errors")
        env {"XDG_STATE_HOME" (support/path "state") "FZF_DEFAULT_COMMAND" ""
             "FZF_DEFAULT_OPTS" "--bind=ctrl-u:half-page-up"}]
    (spit script (str "source " support/repo-root "/.vim/plugin/git_helpers.vim\n"
                      commands "\ncall writefile(v:errors, '" errors "')\n"
                      "if !empty(v:errors) | cquit | endif\nqa!\n"))
    (let [{:keys [exit out err]} (support/capture {:extra-env env :dir support/*temp-dir*}
                                               ["vim" "-Nu" (str support/repo-root "/.vimrc")
                                                "-i" "NONE" "-es" "-S" script])]
      (is (zero? exit) (str out err (when (fs/exists? errors) (slurp errors)))))))

(defn- git! [& args]
  (let [{:keys [exit out err]} (support/capture (into ["git" "-C" support/*temp-dir*] args))]
    (is (zero? exit) (str out err))
    (str/trim out)))

(deftest git-helpers-report-failures-without-commit-links
  (support/write-file! (support/path "file.txt") "hello\n")
  (vim! (str "edit " (support/path "file.txt") "\n"
             "let output = execute('Blame')\n"
             "call assert_match('not a git repository', output)\n"
             "call assert_notmatch('Commit:', output)\n"
             "let output = execute('LogSearch')\n"
             "call assert_match('not a git repository', output)\n"
             "call assert_notmatch('Commit:', output)")))

(deftest git-helpers-use-file-directory-and-visual-line-range
  (git! "init" "-q")
  (git! "config" "user.name" "Config Test")
  (git! "config" "user.email" "test@example.invalid")
  (git! "remote" "add" "origin" "git@github.com:example/test.git")
  (let [file (support/write-file! (support/path "file with spaces.txt") "alpha\nmiddle\nomega\n")]
    (git! "add" ".")
    (git! "commit" "-qm" "Initial lines")
    (let [first-commit (git! "rev-parse" "HEAD")]
      (spit file "alpha\nomega\n")
      (git! "commit" "-qam" "Join lines")
      (let [second-commit (git! "rev-parse" "HEAD")]
        (vim! (str "execute 'edit ' . fnameescape('" file "')\ncd /\n"
                   "let output = execute('Blame')\n"
                   "call assert_match('/commit/" first-commit "', output)\n"
                   "let output = execute('1,2LogSearch')\n"
                   "call assert_match('/commit/" second-commit "', output)\n"
                   "call assert_notmatch('/commit/" first-commit "', output)\n"
                   "redir => selected\n"
                   "call feedkeys(\"ggVj\" . nr2char(92) . 'gs', 'xt')\nredir END\n"
                   "call assert_match('/commit/" second-commit "', selected)"))))))

(deftest fzf-lists-files-outside-git-and-preserves-options
  (support/write-file! (support/path "visible.txt") "hello\n")
  (vim! (str "call assert_match('--bind=ctrl-u:half-page-up', $FZF_DEFAULT_OPTS)\n"
             "call assert_match('--reverse', $FZF_DEFAULT_OPTS)\n"
             "let files = system($FZF_DEFAULT_COMMAND)\n"
             "call assert_equal(0, v:shell_error)\n"
             "call assert_match('visible.txt', files)")))

(deftest large-file-cursorline-stays-off-and-recovery-files-are-created
  (support/write-file! (support/path "large.txt") (apply str (repeat 220000 "line\n")))
  (support/write-file! (support/path "small.txt") "before\n")
  (vim! (str "edit " (support/path "large.txt") "\n"
             "call assert_equal(0, &l:cursorline)\n"
             "split " (support/path "small.txt") "\n"
             "call assert_equal(1, &l:cursorline)\n"
             "call assert_equal(1, &l:swapfile)\n"
             "call assert_equal(1, &writebackup)\n"
             "call assert_equal(1, &l:undofile)\n"
             "call assert_match('/state/vim/swap/', swapname('%'))\n"
             "call setline(1, 'after')\nwrite\n"
             "call assert_true(filereadable(undofile(expand('%:p'))))\n"
             "wincmd p\ncall assert_equal(0, &l:cursorline)")))

(deftest bat-redirects-plain-contents
  (let [contents "puts 'hello'\n"
        file (support/write-file! (support/path "sample.rb") contents)
        {:keys [exit out err]} (support/capture
                               {:extra-env {"BAT_CONFIG_PATH" (str support/repo-root "/bat/config")}}
                               ["bat" file])]
    (is (zero? exit) (str out err))
    (is (= contents out))))

(support/run-tests! 'editor-config-test)
