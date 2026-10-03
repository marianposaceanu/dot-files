(require '[babashka.classpath :as classpath]
         '[babashka.fs :as fs]
         '[cheshire.core :as json]
         '[clojure.java.io :as io])

(def ^:private repo-root
  (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))

(classpath/add-classpath repo-root)
(require '[bootstrap.lib.common :as common]
         '[bootstrap.lib.ruby-warnings :as ruby-warnings])

(def ^:private usage "Usage: bb bootstrap/checks/check_configs.clj")

(defn- repo-path [& parts]
  (str (apply fs/path repo-root parts)))

(defn- parse-clojure-file! [path]
  (with-open [reader (java.io.PushbackReader. (io/reader (str path)))]
    (loop []
      (when-not (= ::eof (read {:eof ::eof} reader))
        (recur)))))

(defn- check-shell-scripts! []
  (common/info "Checking shell script syntax...")
  (doseq [script (sort (concat
                        (fs/glob (repo-path "bootstrap") "**.sh")
                        (fs/glob (repo-path "benchmarks") "*.sh")))]
    (common/run! ["bash" "-n" (str script)])))

(defn- check-babashka-scripts! []
  (common/info "Checking Babashka script syntax...")
  (doseq [script (sort (fs/glob (repo-path "bootstrap") "**.clj"))]
    (parse-clojure-file! script)))

(defn- check-shell-configs! []
  (common/info "Checking Bash config syntax...")
  (common/run! ["bash" "-n" (repo-path ".bashrc")])

  (common/info "Checking Zsh config syntax...")
  (doseq [config [".zprofile" ".zshrc" ".zlogin"]]
    (common/run! ["zsh" "-n" (repo-path config)])))

(defn- check-application-configs! []
  (common/info "Checking Git, Amp, Claude Code, and bat configs...")
  (common/run! {:out :string}
               ["git" "config" "-f" (repo-path ".gitconfig") "--list"])
  (json/parse-string (slurp (repo-path "amp" "settings.json")))
  (json/parse-string (slurp (repo-path "claude" "settings.json")))
  (json/parse-string (slurp (repo-path "claude" "config.json")))
  (if-let [bat (common/command-path "bat")]
    (common/run! {:out :string
                  :extra-env {"BAT_CONFIG_PATH" (repo-path "bat" "config")}}
                 [bat "/dev/null"])
    (common/info "Skipping bat config validation (bat not found).")))

(defn- run-ruby! [warnings opts & args]
  (ruby-warnings/run! warnings
                      {:label "Ruby used by config checks"
                       :ruby (or (common/command-path "ruby") "ruby")}
                      opts args))

(defn- check-installer! [warnings]
  (common/info "Checking macOS installer idempotence...")
  (run-ruby! warnings {:out :string} (repo-path "test" "install_macos_test.rb")))

(defn- check-published-site! [warnings]
  (common/info "Checking generated tutorial pages...")
  (run-ruby! warnings {} (repo-path "bootstrap" "site" "build_tutorial_pages.rb") "--check")

  (common/info "Checking published site contract...")
  (run-ruby! warnings {} (repo-path "bootstrap" "site" "validate_site.rb")))

(defn- check-vim! [warnings]
  (common/info "Checking editor behavior and bat output...")
  (run-ruby! warnings {:out :string} (repo-path "test" "editor_config_test.rb"))
  (common/info "Checking Vim config load...")
  (common/run!
   ["vim" "-Nu" (repo-path ".vimrc") "-i" "NONE" "-n" "-es" "-c" "qall"]))

(defn- check-ghostty! []
  (if-let [ghostty (common/command-path "ghostty")]
    (do
      (common/info "Validating Ghostty config...")
      (common/run! {:out :string} [ghostty "+validate-config"]))
    (common/info "Skipping Ghostty validation (ghostty not found).")))

(defn -main [& args]
  (when (seq args)
    (common/usage-error! usage))

  (common/start-panel
   "DOT-FILES :: CONFIG CHECKS"
   "Validating scripts, generated pages, Vim, and Ghostty")

  (let [warnings (atom {})]
    (try
      (common/info "Inspecting Ruby and RVM gem environments...")
      (ruby-warnings/inspect! warnings)
      (check-shell-scripts!)
      (check-babashka-scripts!)
      (check-shell-configs!)
      (check-application-configs!)
      (check-installer! warnings)
      (check-published-site! warnings)
      (check-vim! warnings)
      (check-ghostty!)

      (println)
      (common/success-panel
       "CHECKS COMPLETE"
       "All configuration checks passed.")
      (finally
        (ruby-warnings/report! warnings)))))

(common/run-script! -main *command-line-args*)
