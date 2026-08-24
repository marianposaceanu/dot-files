(require '[babashka.classpath :as classpath]
         '[babashka.fs :as fs])

(def ^:private repo-root
  (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))

(classpath/add-classpath repo-root)
(require '[bootstrap.lib.common :as common])

(def ^:private usage "Usage: bb bootstrap/setup/install_brew_deps.clj")

(defn -main [& args]
  (when (seq args)
    (common/usage-error! usage))

  (let [brew (common/command-path "brew")
        brewfile (fs/path repo-root "Brewfile")]
    (when-not brew
      (throw (ex-info "Homebrew is not installed or not in PATH." {})))
    (when-not (fs/regular-file? brewfile)
      (throw (ex-info (str "Brewfile not found at " brewfile) {})))

    (common/start-panel
     "HOMEBREW DEPENDENCIES"
     "Installing the repository Brewfile")

    (common/info "Updating Homebrew metadata...")
    (common/run! [brew "update"])

    (common/info "Installing dependencies from Brewfile...")
    (common/run! (common/brew-bundle-command brew brewfile))

    (println)
    (common/success-panel
     "DEPENDENCIES COMPLETE"
     "Brewfile dependencies are installed.")))

(common/run-script! -main *command-line-args*)
