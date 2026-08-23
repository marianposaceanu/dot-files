(require '[babashka.fs :as fs]
         '[clojure.java.io :as io])

(def repo-root
  (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))

(load-file (str (fs/path repo-root "bootstrap/lib/common.clj")))

(when (seq *command-line-args*)
  (binding [*out* *err*]
    (println "Usage: bb bootstrap/checks/check_configs.clj"))
  (System/exit 2))

(defn repo-path [& parts]
  (str (apply fs/path repo-root parts)))

(defn parse-clojure-file! [path]
  (with-open [reader (java.io.PushbackReader. (io/reader (str path)))]
    (loop []
      (when-not (= ::eof (read {:eof ::eof} reader))
        (recur)))))

(try
  (bootstrap.lib.common/info "Checking shell script syntax...")
  (doseq [script (concat
                  (sort (fs/glob (repo-path "bootstrap") "**.sh"))
                  (map #(apply repo-path %)
                       [["benchmarks" "benchmark_ripgrep_native.sh"]
                        ["benchmarks" "benchmark_ctags_native.sh"]
                        ["benchmarks" "benchmark_git_native.sh"]
                        ["benchmarks" "profile_vim_plugins.sh"]
                        ["benchmarks" "profile_vim_plugins_median.sh"]]))]
    (bootstrap.lib.common/run! ["bash" "-n" (str script)]))

  (bootstrap.lib.common/info "Checking Babashka script syntax...")
  (doseq [script (sort (fs/glob (repo-path "bootstrap") "**.clj"))]
    (parse-clojure-file! script))

  (bootstrap.lib.common/info "Checking Zsh config syntax...")
  (doseq [config [".zprofile" ".zshrc" ".zlogin"]]
    (bootstrap.lib.common/run! ["zsh" "-n" (repo-path config)]))

  (bootstrap.lib.common/info "Checking macOS installer idempotence...")
  (bootstrap.lib.common/run!
   ["env" "-u" "GEM_HOME" "-u" "GEM_PATH" "ruby"
    (repo-path "test" "install_macos_test.rb")])

  (bootstrap.lib.common/info "Checking tutorial page generator...")
  (bootstrap.lib.common/run!
   {:out :string}
   ["env" "-u" "GEM_HOME" "-u" "GEM_PATH" "ruby" "-c"
    (repo-path "bootstrap" "site" "build_tutorial_pages.rb")])

  (bootstrap.lib.common/info "Checking published site contract...")
  (bootstrap.lib.common/run!
   ["env" "-u" "GEM_HOME" "-u" "GEM_PATH" "ruby"
    (repo-path "bootstrap" "site" "validate_site.rb")])

  (bootstrap.lib.common/info "Checking Vim config load...")
  (bootstrap.lib.common/run!
   ["vim" "-Nu" (repo-path ".vimrc") "-i" "NONE" "-n" "-es" "-c" "qall"])

  (if-let [ghostty (bootstrap.lib.common/command-path "ghostty")]
    (do
      (bootstrap.lib.common/info "Validating Ghostty config...")
      (bootstrap.lib.common/run! {:out :string} [ghostty "+validate-config"]))
    (bootstrap.lib.common/info "Skipping Ghostty validation (ghostty not found)."))

  (bootstrap.lib.common/success "All checks passed.")
  (catch Exception error
    (bootstrap.lib.common/abort! error)))
