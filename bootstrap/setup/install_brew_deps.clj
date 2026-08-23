(require '[babashka.fs :as fs])

(def repo-root
  (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))

(load-file (str (fs/path repo-root "bootstrap/lib/common.clj")))

(when (seq *command-line-args*)
  (binding [*out* *err*]
    (println "Usage: bb bootstrap/setup/install_brew_deps.clj"))
  (System/exit 2))

(try
  (let [brew (bootstrap.lib.common/command-path "brew")
        brewfile (str (fs/path repo-root "Brewfile"))]
    (when-not brew
      (throw (ex-info "Homebrew is not installed or not in PATH." {})))
    (when-not (fs/regular-file? brewfile)
      (throw (ex-info (str "Brewfile not found at " brewfile) {})))

    (bootstrap.lib.common/start-panel
     "HOMEBREW DEPENDENCIES"
     "Installing the repository Brewfile")

    (bootstrap.lib.common/info "Updating Homebrew metadata...")
    (bootstrap.lib.common/run! [brew "update"])

    (bootstrap.lib.common/info "Installing dependencies from Brewfile...")
    (let [help (:out (bootstrap.lib.common/result [brew "bundle" "--help"]))
          command (cond-> [brew "bundle" "--file" brewfile]
                    (re-find #"--no-lock" help) (conj "--no-lock"))]
      (bootstrap.lib.common/run! command))

    (println)
    (bootstrap.lib.common/success-panel
     "DEPENDENCIES COMPLETE"
     "Brewfile dependencies are installed."))
  (catch Exception error
    (bootstrap.lib.common/abort! error)))
