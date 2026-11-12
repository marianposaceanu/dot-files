(ns integration.install-macos-test
  (:require [babashka.fs :as fs]
            [cheshire.core :as json]
            [clojure.string :as str]
            [clojure.test :refer [deftest is testing use-fixtures]]
            [test.support :as support]))

(defn- home-path [& parts] (apply support/path "home" parts))
(defn- log-lines [] (str/split-lines (slurp (support/path "commands.log"))))
(defn- backups [path] (mapv str (sort (fs/glob (fs/parent path) (str (fs/file-name path) ".backup.*")))))
(defn- read-json [path] (json/parse-string (slurp path)))

(defn- setup! []
  (fs/create-dirs (home-path))
  (fs/create-dirs (support/path "bin"))
  (fs/create-sym-link (support/path "bin/bb") (fs/absolutize support/bb))
  (spit (support/path "clt-state") "")
  (spit (home-path ".zshrc") "original zsh config\n")
  (doseq [fixture (fs/list-dir (fs/path support/repo-root "test/fixtures/install_macos"))]
    (support/executable! (support/path "bin" (fs/file-name fixture)) (slurp (str fixture)))))

(defn- with-installer [test!]
  (setup!)
  (test!))

(use-fixtures :each support/with-temp-dir with-installer)

(defn- invoke-installer
  ([] (invoke-installer {}))
  ([{:keys [interactive? fail-brew? fail-rvm? timings?]}]
   (let [env {"HOME" (home-path)
              "PATH" (str/join ":" [(support/path "bin") "/usr/bin" "/bin" "/usr/sbin" "/sbin"])
              "INSTALLER_TEST_BB_BIN" support/bb
              "INSTALLER_TEST_LOG" (support/path "commands.log")
              "INSTALLER_TEST_BREW_STATE" (support/path "brew-state")
              "INSTALLER_TEST_CLT_STATE" (support/path "clt-state")
              "INSTALLER_TEST_RESIZE" (if interactive? "1" "0")
              "INSTALLER_TEST_FAIL_BREW" (if fail-brew? "1" "0")
              "INSTALLER_TEST_FAIL_RVM" (if fail-rvm? "1" "0")
              "GHOSTTY_APP_PATH" (home-path "Applications/Ghostty.app")
              "TERM" "xterm-256color"}
         command (cond-> [support/bb (str support/repo-root "/bootstrap/install_macos.clj") "--skip-checks"]
                   timings? (conj "--timings"))
         invocation (if interactive?
                   (into ["/usr/bin/script" "-q" "/dev/null" "/bin/bash" "-c"
                          "stty rows 24 cols 64; exec \"$@\"" "installer-progress-test"] command)
                   command)]
     (support/capture {:extra-env env} invocation))))

(defn- run-installer!
  ([] (run-installer! {}))
  ([options]
   (let [{:keys [exit out err]} (invoke-installer options)]
     (is (zero? exit) (str "installer failed:\n" out err))
     out)))

(deftest upgrades-only-installed-ai-tools-test
  (let [output (run-installer!)]
    (doseq [tool ["amp" "claude" "codex"]]
      (is (str/includes? output (str "Skipping " tool ": not installed on PATH.")))))
  (doseq [tool ["amp" "claude" "npm"]]
    (support/executable!
     (support/path "bin" tool)
     (str "#!/bin/sh\nprintf '" tool " %s\\n' \"$*\" >> \"$INSTALLER_TEST_LOG\"\n")))
  (let [prefix (support/path "npm-prefix")
        codex (support/executable! (str prefix "/lib/node_modules/@openai/codex/bin/codex.js")
                                   "#!/bin/sh\nexit 99\n")]
    (fs/create-sym-link (support/path "bin/codex") codex)
    (run-installer!)
    (is (some #{"amp update"} (log-lines)))
    (is (some #{"claude update"} (log-lines)))
    (is (some #{(str "npm install --global --prefix " (fs/canonicalize prefix)
                    " @openai/codex@latest")} (log-lines))))
  (testing "Homebrew installs keep their package manager and Claude release channel"
    (doseq [[tool cask] [["claude" "claude-code@latest"] ["codex" "codex"]]]
      (fs/delete (support/path "bin" tool))
      (fs/create-sym-link
       (support/path "bin" tool)
       (support/executable! (support/path "homebrew/Caskroom" cask "1.0" tool)
                            "#!/bin/sh\nexit 99\n")))
    (run-installer!)
    (doseq [command ["brew upgrade --cask claude-code@latest" "brew upgrade --cask codex"]]
      (is (some #{command} (log-lines)))))
  (testing "Unknown Codex installations are not replaced"
    (fs/delete (support/path "bin/codex"))
    (support/executable! (support/path "bin/codex") "#!/bin/sh\nexit 99\n")
    (is (str/includes? (run-installer!) "Skipping codex: unrecognized installation")))
  (testing "An upgrade failure stops setup"
    (support/executable! (support/path "bin/amp") "#!/bin/sh\necho 'upgrade failed' >&2\nexit 42\n")
    (let [{:keys [exit out err]} (invoke-installer)]
      (is (not (zero? exit)))
      (is (str/includes? (str out err) "upgrade failed"))
      (is (not (str/includes? out "SETUP COMPLETE"))))))

(deftest two-runs-install-once-and-do-not-create-duplicate-backups-test
  (testing "Repeated setup preserves user configuration and avoids duplicate installations or backups"
    (let [claude-path (home-path ".claude.json")
          claude-config {"copyOnSelect" false "projects" {"/example" {"trusted" true}}}
          brewfile (slurp (str support/repo-root "/Brewfile"))]
      (spit claude-path (json/generate-string claude-config))
      (doseq [entry ["tap \"marianposaceanu/tap\"" "tap \"borkdude/brew\""
                     "brew \"babashka\"" "brew \"mextdisplay\"" "brew \"ruby\"" "brew \"vim\""]]
        (is (str/includes? brewfile (str entry "\n"))))
      (let [first-output (run-installer!)
            zsh-backups (backups (home-path ".zshrc"))
            claude-backups (backups claude-path)]
        (doseq [message ["╭─ DOT-FILES :: MACOS SETUP" "Linked repository path" "╭─ SETUP COMPLETE"
                         "╰─ Next: restart the terminal or run source ~/.zshrc"
                         "[##################################################] 100%"]]
          (is (str/includes? first-output message)))
        (is (not (str/includes? first-output "\u001b")))
        (is (fs/sym-link? (home-path "dot-files")))
        (doseq [[target source] [["dot-files" ""] [".ignore" ".ignore"] [".zshrc" ".zshrc"]
                                 [".codex/config.toml" "llm-harnesses/codex/config.toml"]
                                 [".claude/settings.json" "llm-harnesses/claude/settings.json"]
                                 [".claude/output-styles/amp.md" "llm-harnesses/claude/output-styles/amp.md"]
                                 [".config/amp/settings.json" "llm-harnesses/amp/settings.json"]]]
          (is (= (str (fs/canonicalize (fs/path support/repo-root source)))
                 (str (fs/canonicalize (home-path target))))))
        (is (not (fs/sym-link? claude-path)))
        (is (= (assoc claude-config "copyOnSelect" true) (read-json claude-path)))
        (is (= 1 (count claude-backups)))
        (is (= claude-config (read-json (first claude-backups))))
        (is (fs/regular-file? (home-path ".oh-my-zsh/oh-my-zsh.sh")))
        (is (fs/executable? (support/path "homebrew/opt/mextdisplay/bin/mextdisplay")))
        (is (fs/executable? (home-path "Applications/Ghostty.app/Contents/MacOS/ghostty")))
        (is (= 1 (count zsh-backups)))
        (is (= "original zsh config\n" (slurp (first zsh-backups))))
        (let [second-output (run-installer!)]
          (doseq [message ["Repository path is ready" "Ghostty is already installed" "Oh My Zsh is already installed"
                           "╭─ [05/10] RVM Ruby versions" "RVM Ruby 4.0.7 is already installed."
                           "╭─ [08/10] Pinned Vim plugins" "✓ Pinned Vim plugins are ready."
                           "╭─ [09/10] Configuration links" "✓ Configuration links: 17 unchanged, 0 updated, 0 backups."
                           "╭─ [10/10] Validation"]]
            (is (str/includes? second-output message)))
          (is (not (str/includes? second-output "Already linked:")))
          (is (= zsh-backups (backups (home-path ".zshrc"))))
          (is (= claude-backups (backups claude-path))))
        (let [commands (log-lines)
              counts (frequencies commands)]
          (doseq [[command expected] [["brew install --cask ghostty" 1] ["brew update" 2]
                                      ["git submodule --quiet sync --recursive" 2]
                                      ["git submodule --quiet update --init --recursive" 2]
                                      ["rvm installer" 1] ["rvm install ruby-4.0.7" 1]
                                      ["rvm --default use ruby-4.0.7" 1]]]
            (is (= expected (get counts command 0)) command))
          (is (= 1 (count (filter #(str/starts-with? % "git clone ") commands))))
          (is (= 2 (count (filter #(str/starts-with? % "brew bundle --file ") commands)))))))))

(deftest requests-command-line-tools-and-stops-for-their-installer-test
  (testing "Missing Command Line Tools stop setup before installing dependencies"
    (fs/delete (support/path "clt-state"))
    (let [{:keys [exit out err]} (invoke-installer)]
      (is (not (zero? exit)))
      (is (not (str/includes? out "Ensuring Homebrew")))
      (is (str/includes? err "Command Line Tools installation was requested"))
      (is (some #{"xcode-select --install"} (log-lines)))
      (is (not (fs/exists? (home-path "dot-files")))))))

(deftest rvm-check-reports-missing-versions-without-installing-test
  (testing "Check mode reports missing Ruby versions without changing the environment"
    (let [{:keys [exit out err]}
          (support/capture {:extra-env {"HOME" (home-path)
                                        "PATH" (str/join ":" [(support/path "bin") "/usr/bin" "/bin"])}}
                           [support/bb (str support/repo-root "/bootstrap/setup/install_rvm.clj") "--check"])]
      (is (not (zero? exit)))
      (is (str/includes? (str out err) "RVM Ruby 4.0.7 is missing or does not run correctly."))
      (is (not (fs/exists? (home-path ".rvm"))))
      (is (not (fs/exists? (support/path "commands.log")))))))

(deftest repairs-rvm-default-without-reinstalling-or-removing-old-rubies-test
  (testing "Repairing the RVM default preserves installed Ruby versions"
    (run-installer!)
    (let [old-ruby (support/executable! (home-path ".rvm/rubies/ruby-3.4.7/bin/ruby") "#!/bin/sh\nprintf 3.4.7\n")
          default (home-path ".rvm/rubies/default")]
      (fs/delete default)
      (fs/create-sym-link default (home-path ".rvm/rubies/ruby-3.4.7"))
      (run-installer!)
      (is (= (fs/canonicalize (home-path ".rvm/rubies/ruby-4.0.7")) (fs/canonicalize default)))
      (is (fs/executable? old-ruby))
      (let [counts (frequencies (log-lines))]
        (is (= 1 (get counts "rvm install ruby-4.0.7")))
        (is (= 2 (get counts "rvm --default use ruby-4.0.7")))))))

(deftest rvm-install-failure-stops-setup-test
  (testing "A failed Ruby installation prevents setup from reporting completion"
    (let [{:keys [exit out err]} (invoke-installer {:fail-rvm? true})]
      (is (not (zero? exit)))
      (is (str/includes? (str out err) "simulated RVM install failure"))
      (is (not (str/includes? out "SETUP COMPLETE")))
      (is (not (fs/exists? (home-path ".rvm/rubies/default")))))))

(deftest repairs-a-ghostty-receipt-without-an-application-test
  (testing "A stale Homebrew receipt triggers a Ghostty reinstall"
    (spit (support/path "brew-state") "")
    (run-installer!)
    (is (fs/executable? (home-path "Applications/Ghostty.app/Contents/MacOS/ghostty")))
    (let [counts (frequencies (log-lines))]
      (is (= 1 (get counts "brew reinstall --cask ghostty" 0)))
      (is (= 0 (get counts "brew install --cask ghostty" 0))))))

(deftest optional-stage-timing-report-test
  (testing "Timing output includes stage duration and percentage of total time"
    (let [output (run-installer! {:timings? true})]
      (is (str/includes? output "╭─ STAGE TIMINGS"))
      (doseq [pattern [#"(?m)^│  Command-line dependencies +\d+\.\d{3}s +\d+\.\d%$"
                       #"(?m)^│  Pinned Vim plugins +\d+\.\d{3}s +\d+\.\d%$"
                       #"(?m)^╰─ Total +\d+\.\d{3}s +100\.0%$"]]
        (is (re-find pattern output))))))

(deftest interactive-progress-stays-reserved-during-output-and-resize-test
  (testing "Interactive progress remains visible and monotonic while children resize the terminal"
    (let [output (run-installer! {:interactive? true})
          percentages (mapv #(parse-long (second %)) (re-seq #"\[[# ]+\] +(\d+)%" output))]
      (doseq [region ["\u001b[1;23r" "\u001b[1;29r" "\u001b[1;17r" "\u001b[1;18r"]]
        (is (str/includes? output region)))
      (doseq [percent [10 31 40 85 99 100]] (is (some #{percent} percentages)))
      (is (= (sort percentages) percentages) "progress should never move backwards")
      (is (> (count (distinct percentages)) 20))
      (is (< (str/index-of output " 31%") (str/index-of output "Installing dependencies from Brewfile")))
      (is (< (str/index-of output "\u001b[1;29r") (str/index-of output "growth-child-still-running")))
      (is (< (str/index-of output "\u001b[1;17r") (str/index-of output "shrink-child-still-running"))))))

(deftest dependency-failure-is-reported-without-a-completion-panel-test
  (testing "Dependency failures produce a failure panel instead of reporting success"
    (let [{:keys [exit out err]} (invoke-installer {:fail-brew? true})
          output (str out err)]
      (is (not (zero? exit)))
      (is (str/includes? output "simulated brew bundle failure"))
      (is (not (re-find #"\[[# ]+\] +100%" output)))
      (is (not (str/includes? output "SETUP COMPLETE")))
      (is (str/includes? output "╭─ COMMAND FAILED")))))

(deftest interactive-failure-restores-the-full-terminal-region-test
  (testing "Interactive failures restore the terminal scrolling region"
    (let [{:keys [exit out err]} (invoke-installer {:interactive? true :fail-brew? true})
          output (str out err)]
      (is (not (zero? exit)))
      (is (str/includes? output "simulated brew bundle failure"))
      (is (not (re-find #"\[[# ]+\] +100%" output)))
      (is (not (str/includes? output "SETUP COMPLETE")))
      (is (> (str/last-index-of output "\u001b[1;18r") (str/index-of output "simulated brew bundle failure"))))))
