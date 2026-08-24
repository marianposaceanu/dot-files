(require '[babashka.classpath :as classpath]
         '[babashka.fs :as fs]
         '[cheshire.core :as json]
         '[clojure.java.io :as io])

(def ^:private repo-root
  (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))

(classpath/add-classpath repo-root)
(require '[bootstrap.lib.common :as common])

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
  (common/info "Checking Git, Amp, and bat configs...")
  (common/run! {:out :string}
               ["git" "config" "-f" (repo-path ".gitconfig") "--list"])
  (json/parse-string (slurp (repo-path "amp" "settings.json")))
  (if-let [bat (common/command-path "bat")]
    (common/run! {:out :string}
                 [bat "--config-file" (repo-path "bat" "config")
                  "--plain" "--color=never" "/dev/null"])
    (common/info "Skipping bat config validation (bat not found).")))

(defn- run-ruby! [& args]
  (common/run! (into ["env" "-u" "GEM_HOME" "-u" "GEM_PATH" "ruby"] args)))

(defn- check-installer! []
  (common/info "Checking macOS installer idempotence...")
  (run-ruby! (repo-path "test" "install_macos_test.rb")))

(defn- check-published-site! []
  (common/info "Checking generated tutorial pages...")
  (run-ruby! (repo-path "bootstrap" "site" "build_tutorial_pages.rb") "--check")

  (common/info "Checking published site contract...")
  (run-ruby! (repo-path "bootstrap" "site" "validate_site.rb")))

(defn- check-vim! []
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

  (check-shell-scripts!)
  (check-babashka-scripts!)
  (check-shell-configs!)
  (check-application-configs!)
  (check-installer!)
  (check-published-site!)
  (check-vim!)
  (check-ghostty!)

  (println)
  (common/success-panel
   "CHECKS COMPLETE"
   "All configuration checks passed."))

(common/run-script! -main *command-line-args*)
