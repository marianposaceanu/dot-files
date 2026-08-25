(require '[babashka.classpath :as classpath]
         '[babashka.fs :as fs])

(def ^:private script-repo-root
  (-> *file* fs/parent fs/parent fs/canonicalize str))

(classpath/add-classpath script-repo-root)
(require '[bootstrap.lib.common :as common]
         '[bootstrap.lib.progress :as progress])

(def ^:private total-stages 9)

(def ^:private required-formulas
  [{:formula "babashka" :executable "bb"}
   {:formula "mextdisplay" :executable "mextdisplay"}
   {:formula "ruby" :executable "ruby"}
   {:formula "vim" :executable "vim"}])

(defn- dot-files-repo? [path]
  (and path
       (fs/regular-file? (fs/path path "Brewfile"))
       (fs/regular-file? (fs/path path ".vimrc"))
       (fs/directory? (fs/path path "bootstrap"))))

(defn- ancestor-paths [path]
  (take-while some? (iterate fs/parent path)))

(defn- process-command []
  (.. (java.lang.ProcessHandle/current) info command (orElse nil)))

(defn- find-repo-root [home]
  (let [source-file (when (and *file* (fs/exists? *file*)) *file*)
        candidates (concat
                    [(System/getenv "DOT_FILES_REPO")]
                    (when source-file (ancestor-paths (fs/parent source-file)))
                    [(System/getProperty "user.dir")
                     (fs/path home "dot-files")])]
    (or (some #(when (dot-files-repo? %) (str (fs/canonicalize %)))
              (distinct (remove nil? candidates)))
        (throw (ex-info
                "Unable to find the dot-files repository. Run from the repository or set DOT_FILES_REPO."
                {})))))

(defn- find-brew []
  (or (common/command-path "brew")
      (some #(when (fs/executable? %) %)
            ["/opt/homebrew/bin/brew" "/usr/local/bin/brew"])))

(defn- usage []
  (println "Usage:")
  (println "  bb bootstrap/install_macos.clj [--skip-checks] [--timings]")
  (println)
  (println "Options:")
  (println "  --skip-checks  Skip final repository and environment checks")
  (println "  --timings      Print elapsed time for each setup stage")
  (println "  -h, --help     Show this help"))

(defn- parse-options [args]
  (reduce
   (fn [options arg]
     (case arg
       "--skip-checks" (assoc options :skip-checks true)
       "--timings" (assoc options :show-timings true)
       (do
         (binding [*out* *err*]
           (println (str "Unknown option: " arg)))
         (usage)
         (System/exit 2))))
   {:skip-checks false :show-timings false}
   args))

(defn- initial-state [options]
  (let [home (or (System/getenv "HOME") (System/getProperty "user.home"))]
    {:options options
     :repo-root (find-repo-root home)
     :expected-repo (str (fs/path home "dot-files"))
     :ghostty-app (or (System/getenv "GHOSTTY_APP_PATH")
                      "/Applications/Ghostty.app")
     :oh-my-zsh-dir (str (fs/path home ".oh-my-zsh"))
     :brew (find-brew)
     :bb (or (common/command-path "bb") (process-command) "bb")
     :child-env {}
     :timings []}))

(defn- run-command!
  ([state command]
   (common/run! {:extra-env (:child-env state)} command))
  ([state options command]
   (let [extra-env (merge (:child-env state) (:extra-env options))]
     (common/run! (assoc options :extra-env extra-env) command))))

(defn- run-stage! [state number title action]
  (common/section number total-stages title)
  (let [started (System/nanoTime)
        next-state (action state)
        elapsed-seconds (/ (- (System/nanoTime) started) 1000000000.0)]
    (progress/update! number total-stages)
    (update next-state :timings conj
            {:title title :seconds elapsed-seconds})))

(defn- find-ghostty [{:keys [ghostty-app]}]
  (or (common/command-path "ghostty")
      (let [candidate (str (fs/path ghostty-app "Contents/MacOS/ghostty"))]
        (when (fs/executable? candidate) candidate))))

(defn- timing-line [title seconds percent]
  (format "%-30s %7.3fs %5.1f%%" title seconds percent))

(defn- print-timings [{:keys [options timings]}]
  (when (:show-timings options)
    (let [total (reduce + (map :seconds timings))
          percent-of-total #(if (zero? total) 0.0 (* 100.0 (/ % total)))]
      (println)
      (apply common/start-panel "STAGE TIMINGS"
             (concat
              (for [{:keys [title seconds]} timings]
                (timing-line title seconds (percent-of-total seconds)))
              [(timing-line "Total" total 100.0)])))))

(defn- ensure-command-line-tools! [state]
  (when-not (common/successful? ["xcode-select" "-p"])
    (common/run!
     {:continue true :out :string :err :string}
     ["xcode-select" "--install"])
    (throw (ex-info
            "Command Line Tools installation was requested; finish it, then rerun this installer."
            {})))
  (common/success "Apple Command Line Tools are available.")
  state)

(defn- ensure-repository-path! [{:keys [expected-repo repo-root] :as state}]
  (cond
    (fs/directory? expected-repo)
    (if (= repo-root (common/canonical expected-repo))
      (common/success
       (str "Repository path is ready: " expected-repo))
      (throw (ex-info
              (str expected-repo " points to "
                   (common/canonical expected-repo)
                   " instead of " repo-root)
              {})))

    (common/path-present? expected-repo)
    (throw (ex-info (str expected-repo " exists but is not this repository") {}))

    :else
    (do
      (fs/create-sym-link expected-repo repo-root)
      (common/success
       (str "Linked repository path: " expected-repo " -> " repo-root))))
  state)

(defn- configure-homebrew-env [state brew]
  (let [prefix (common/capture [brew "--prefix"])
        path (str (fs/path prefix "bin") ":"
                  (fs/path prefix "sbin") ":"
                  (System/getenv "PATH"))]
    (-> state
        (assoc :brew brew)
        (assoc :child-env {"HOMEBREW_PREFIX" prefix "PATH" path}))))

(defn- ensure-homebrew! [state]
  (if-let [brew (:brew state)]
    (let [next-state (configure-homebrew-env state brew)]
      (common/success (str "Homebrew is already installed: " brew))
      next-state)
    (do
      (when-not (common/command-path "curl")
        (throw (ex-info "curl is required to install Homebrew." {})))
      (common/info "Installing Homebrew...")
      (run-command!
       state
       ["/bin/bash" "-c"
        (common/capture
         ["curl" "-fsSL"
          "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"])])
      (let [brew (or (find-brew)
                     (throw (ex-info
                             "Homebrew installation completed but brew was not found."
                             {})))
            next-state (configure-homebrew-env state brew)]
        (common/success (str "Homebrew installed: " brew))
        next-state))))

(defn- formula-prefix! [brew {:keys [formula executable]}]
  (let [prefix (common/capture [brew "--prefix" formula])
        binary (str (fs/path prefix "bin" executable))]
    (when-not (fs/executable? binary)
      (throw (ex-info (str formula " is missing from " binary) {})))
    [formula prefix]))

(defn- install-dependencies! [{:keys [brew repo-root] :as state}]
  (let [brewfile (fs/path repo-root "Brewfile")]
    (common/info "Updating Homebrew metadata...")
    (run-command! state [brew "update"])
    (common/info "Installing dependencies from Brewfile...")
    (run-command! state (common/brew-bundle-command brew brewfile))
    (common/success "Brewfile dependencies are installed.")
    (let [prefixes (into {} (map #(formula-prefix! brew %) required-formulas))
          ruby-bin (str (fs/path (get prefixes "ruby") "bin"))
          installed-bb (str (fs/path (get prefixes "babashka") "bin/bb"))
          path (str ruby-bin ":" (get-in state [:child-env "PATH"]))]
      (common/success "Verified mextdisplay, Ruby, and Vim executables.")
      (-> state
          (assoc :bb installed-bb)
          (assoc-in [:child-env "PATH"] path)))))

(defn- install-ghostty! [{:keys [brew ghostty-app] :as state}]
  (if-let [ghostty (find-ghostty state)]
    (common/info (str "Ghostty is already installed: " ghostty))
    (if (common/successful? [brew "list" "--cask" "ghostty"])
      (do
        (common/info "Repairing the Homebrew Ghostty installation...")
        (run-command! state
                      {:extra-env {"HOMEBREW_NO_AUTO_UPDATE" "1"}}
                      [brew "reinstall" "--cask" "ghostty"]))
      (do
        (common/info "Installing Ghostty...")
        (run-command! state
                      {:extra-env {"HOMEBREW_NO_AUTO_UPDATE" "1"}}
                      [brew "install" "--cask" "ghostty"]))))
  (when-not (find-ghostty state)
    (throw (ex-info
            (str "Ghostty was installed but its executable is missing from "
                 ghostty-app)
            {})))
  (common/success "Ghostty is ready.")
  state)

(defn- install-oh-my-zsh! [{:keys [oh-my-zsh-dir] :as state}]
  (let [entrypoint (fs/path oh-my-zsh-dir "oh-my-zsh.sh")]
    (cond
      (fs/regular-file? entrypoint)
      (common/success (str "Oh My Zsh is already installed: " oh-my-zsh-dir))

      (common/path-present? oh-my-zsh-dir)
      (throw (ex-info
              (str oh-my-zsh-dir
                   " exists but is not a complete Oh My Zsh installation")
              {}))

      :else
      (let [candidate (str oh-my-zsh-dir ".install." (random-uuid))]
        (try
          (run-command! state ["git" "clone" "--depth=1"
                               "https://github.com/ohmyzsh/ohmyzsh.git"
                               candidate])
          (fs/move candidate oh-my-zsh-dir)
          (common/success (str "Oh My Zsh installed: " oh-my-zsh-dir))
          (catch Exception error
            (when (common/path-present? candidate)
              (fs/delete-tree candidate))
            (throw error))))))
  state)

(defn- update-submodules! [{:keys [bb repo-root] :as state}]
  (run-command! state [bb (str (fs/path repo-root
                                        "bootstrap/submodules/update_submodules.clj"))])
  (common/success "Pinned Vim plugins are ready.")
  state)

(defn- link-configs! [{:keys [repo-root] :as state}]
  (common/success
   (str "Configuration links: "
        (common/summary (common/link-configs! repo-root))))
  state)

(defn- validate! [{:keys [bb options repo-root] :as state}]
  (if (:skip-checks options)
    (do
      (common/warning "Final checks were skipped. Run these when ready:")
      (println (str "    bb " repo-root "/bootstrap/checks/check_configs.clj"))
      (println (str "    bb " repo-root "/bootstrap/checks/doctor.clj")))
    (let [ghostty (find-ghostty state)]
      (run-command! state [bb (str (fs/path repo-root
                                            "bootstrap/checks/check_configs.clj"))])
      (run-command! state {:out :string} [ghostty "+validate-config"])
      (run-command! state [bb (str (fs/path repo-root
                                            "bootstrap/checks/doctor.clj"))])
      (common/success "Repository, Ghostty, and environment checks passed.")))
  state)

(def ^:private stages
  [["Apple Command Line Tools" ensure-command-line-tools!]
   ["Repository path" ensure-repository-path!]
   ["Homebrew" ensure-homebrew!]
   ["Command-line dependencies" install-dependencies!]
   ["Ghostty" install-ghostty!]
   ["Oh My Zsh" install-oh-my-zsh!]
   ["Pinned Vim plugins" update-submodules!]
   ["Configuration links" link-configs!]
   ["Validation" validate!]])

(defn- run-stages! [initial-state]
  (reduce-kv
   (fn [state index [title action]]
     (run-stage! state (inc index) title action))
   initial-state
   stages))

(defn- run-installer! [options]
  (common/start-panel
   "DOT-FILES :: MACOS SETUP"
   "Idempotent setup powered by Babashka"
   "Existing files are backed up before links are changed")
  (progress/start!)

  (let [final-state (run-stages! (initial-state options))]
    (print-timings final-state)
    (println)
    (progress/complete!)
    (common/success-panel
     "SETUP COMPLETE"
     "Your macOS dot-files environment is ready."
     "Next: restart the terminal or run source ~/.zshrc")))

(defn -main [& args]
  (when (some #{"-h" "--help"} args)
    (usage)
    (System/exit 0))

  (try
    (run-installer! (parse-options args))
    (catch Exception error
      (progress/stop!)
      (common/abort! error))))

(apply -main *command-line-args*)
