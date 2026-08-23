(require '[babashka.fs :as fs]
         '[clojure.string :as str])

(def repo-root
  (-> *file* fs/parent fs/parent fs/canonicalize str))

(load-file (str (fs/path repo-root "bootstrap/lib/common.clj")))

(def total-stages 9)
(def home (or (System/getenv "HOME") (System/getProperty "user.home")))
(def expected-repo (str (fs/path home "dot-files")))
(def ghostty-app (or (System/getenv "GHOSTTY_APP_PATH")
                     "/Applications/Ghostty.app"))
(def oh-my-zsh-dir (str (fs/path home ".oh-my-zsh")))
(def oh-my-zsh-temp (atom nil))
(def timings (atom []))
(def child-env (atom {}))

(defn find-brew []
  (or (bootstrap.lib.common/command-path "brew")
      (some #(when (fs/executable? %) %)
            ["/opt/homebrew/bin/brew" "/usr/local/bin/brew"])))

(def brew-bin (atom (find-brew)))
(def bb-bin
  (or (bootstrap.lib.common/command-path "bb")
      (.. (java.lang.ProcessHandle/current) info command (orElse nil))
      "bb"))

(defn usage []
  (println "Usage: bb bootstrap/install_macos.clj [--skip-checks] [--timings]")
  (println)
  (println "Options:")
  (println "  --skip-checks  Skip final repository and environment checks")
  (println "  --timings      Print elapsed time for each setup stage")
  (println "  -h, --help     Show this help"))

(defn parse-args [args]
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

(when (some #{"-h" "--help"} *command-line-args*)
  (usage)
  (System/exit 0))

(def options (parse-args *command-line-args*))

(defn run!
  ([command]
   (bootstrap.lib.common/run! {:extra-env @child-env} command))
  ([opts command]
   (bootstrap.lib.common/run! (merge {:extra-env @child-env} opts) command)))

(defn stage! [number title action]
  (bootstrap.lib.common/section number total-stages title)
  (let [started (System/nanoTime)]
    (action)
    (swap! timings conj
           {:title title
            :seconds (/ (- (System/nanoTime) started) 1000000000.0)})))

(defn find-ghostty []
  (or (bootstrap.lib.common/command-path "ghostty")
      (let [candidate (str (fs/path ghostty-app "Contents/MacOS/ghostty"))]
        (when (fs/executable? candidate) candidate))))

(defn print-timings []
  (when (:show-timings options)
    (let [total (reduce + (map :seconds @timings))]
      (println)
      (println "╭─ STAGE TIMINGS")
      (doseq [{:keys [title seconds]} @timings]
        (println
         (format "│  %-30s %7.3fs %5.1f%%"
                 title seconds
                 (if (zero? total) 0.0 (* 100.0 (/ seconds total))))))
      (println (format "╰─ %-30s %7.3fs %5.1f%%" "Total" total 100.0)))))

(defn ensure-command-line-tools! []
  (when-not (zero? (:exit (bootstrap.lib.common/result ["xcode-select" "-p"])))
    (bootstrap.lib.common/run!
     {:continue true :out :string :err :string}
     ["xcode-select" "--install"])
    (throw (ex-info
            "Command Line Tools installation was requested; finish it, then rerun this installer."
            {})))
  (bootstrap.lib.common/success "Apple Command Line Tools are available."))

(defn ensure-repository-path! []
  (cond
    (fs/directory? expected-repo)
    (if (= repo-root (bootstrap.lib.common/canonical expected-repo))
      (bootstrap.lib.common/success
       (str "Repository path is ready: " expected-repo))
      (throw (ex-info
              (str expected-repo " points to "
                   (bootstrap.lib.common/canonical expected-repo)
                   " instead of " repo-root)
              {})))

    (bootstrap.lib.common/path-present? expected-repo)
    (throw (ex-info (str expected-repo " exists but is not this repository") {}))

    :else
    (do
      (fs/create-sym-link expected-repo repo-root)
      (bootstrap.lib.common/success
       (str "Linked repository path: " expected-repo " -> " repo-root)))))

(defn configure-homebrew-env! [brew]
  (let [prefix (bootstrap.lib.common/capture [brew "--prefix"])]
    (swap! child-env assoc
           "HOMEBREW_PREFIX" prefix
           "PATH" (str (fs/path prefix "bin") ":"
                       (fs/path prefix "sbin") ":"
                       (System/getenv "PATH")))))

(defn verify-homebrew! []
  (if-let [brew @brew-bin]
    (do
      (configure-homebrew-env! brew)
      (bootstrap.lib.common/success
       (str "Homebrew is already installed: " brew)))
    (do
      (when-not (bootstrap.lib.common/command-path "curl")
        (throw (ex-info "curl is required to install Homebrew." {})))
      (bootstrap.lib.common/info "Installing Homebrew...")
      (run! ["/bin/bash" "-c"
             (bootstrap.lib.common/capture
              ["curl" "-fsSL"
               "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"])])
      (reset! brew-bin (find-brew))
      (when-not @brew-bin
        (throw (ex-info
                "Homebrew installation completed but brew was not found." {})))
      (configure-homebrew-env! @brew-bin)
      (bootstrap.lib.common/success
       (str "Homebrew installed: " @brew-bin)))))

(defn install-dependencies! []
  (run! [bb-bin (str (fs/path repo-root "bootstrap/setup/install_brew_deps.clj"))])
  (let [brew @brew-bin
        requirements {"mextdisplay" "mextdisplay"
                      "ruby" "ruby"
                      "vim" "vim"}
        prefixes (into {}
                       (map (fn [[formula executable]]
                              (let [prefix (str/trim
                                            (:out
                                             (bootstrap.lib.common/result
                                              [brew "--prefix" formula])))
                                    binary (str (fs/path prefix "bin" executable))]
                                (when-not (fs/executable? binary)
                                  (throw (ex-info
                                          (str formula " is missing from " binary) {})))
                                [formula prefix])))
                       requirements)
        ruby-bin (str (fs/path (get prefixes "ruby") "bin"))]
    (swap! child-env assoc
           "PATH" (str ruby-bin ":"
                       (get @child-env "PATH" (System/getenv "PATH"))))
    (bootstrap.lib.common/success
     "Verified mextdisplay, Ruby, and Vim executables.")))

(defn install-ghostty! []
  (let [brew @brew-bin]
    (if-let [ghostty (find-ghostty)]
      (bootstrap.lib.common/info (str "Ghostty is already installed: " ghostty))
      (if (zero? (:exit (bootstrap.lib.common/result
                         [brew "list" "--cask" "ghostty"])))
        (do
          (bootstrap.lib.common/info "Repairing the Homebrew Ghostty installation...")
          (run! {:extra-env (assoc @child-env "HOMEBREW_NO_AUTO_UPDATE" "1")}
                [brew "reinstall" "--cask" "ghostty"]))
        (do
          (bootstrap.lib.common/info "Installing Ghostty...")
          (run! {:extra-env (assoc @child-env "HOMEBREW_NO_AUTO_UPDATE" "1")}
                [brew "install" "--cask" "ghostty"]))))
  (when-not (find-ghostty)
    (throw (ex-info
            (str "Ghostty was installed but its executable is missing from "
                 ghostty-app)
            {})))
  (bootstrap.lib.common/success "Ghostty is ready.")))

(defn install-oh-my-zsh! []
  (let [entrypoint (str (fs/path oh-my-zsh-dir "oh-my-zsh.sh"))]
    (cond
      (fs/regular-file? entrypoint)
      (bootstrap.lib.common/success
       (str "Oh My Zsh is already installed: " oh-my-zsh-dir))

      (bootstrap.lib.common/path-present? oh-my-zsh-dir)
      (throw (ex-info
              (str oh-my-zsh-dir
                   " exists but is not a complete Oh My Zsh installation") {}))

      :else
      (let [candidate (str oh-my-zsh-dir ".install." (java.util.UUID/randomUUID))]
        (reset! oh-my-zsh-temp candidate)
        (run! ["git" "clone" "--depth=1"
               "https://github.com/ohmyzsh/ohmyzsh.git" candidate])
        (fs/move candidate oh-my-zsh-dir)
        (reset! oh-my-zsh-temp nil)
        (bootstrap.lib.common/success
         (str "Oh My Zsh installed: " oh-my-zsh-dir))))))

(defn update-submodules! []
  (run! [bb-bin (str (fs/path repo-root
                              "bootstrap/submodules/update_submodules.clj"))])
  (bootstrap.lib.common/success "Pinned Vim plugins are ready."))

(defn link-configs! []
  (bootstrap.lib.common/success
   (str "Configuration links: "
        (bootstrap.lib.common/summary
         (bootstrap.lib.common/link-configs! repo-root)))))

(defn validate! []
  (if (:skip-checks options)
    (do
      (bootstrap.lib.common/warning "Final checks were skipped. Run these when ready:")
      (println (str "    bb " repo-root "/bootstrap/checks/check_configs.clj"))
      (println (str "    bb " repo-root "/bootstrap/checks/doctor.clj")))
    (let [ghostty (find-ghostty)]
      (run! [bb-bin (str (fs/path repo-root "bootstrap/checks/check_configs.clj"))])
      (run! {:out :string} [ghostty "+validate-config"])
      (run! [bb-bin (str (fs/path repo-root "bootstrap/checks/doctor.clj"))])
      (bootstrap.lib.common/success
       "Repository, Ghostty, and environment checks passed."))))

(try
  (println "╭─ DOT-FILES :: MACOS SETUP")
  (println "│  Idempotent setup powered by Babashka")
  (println "╰─ Existing files are backed up before links are changed")

  (stage! 1 "Apple Command Line Tools" ensure-command-line-tools!)
  (stage! 2 "Repository path" ensure-repository-path!)
  (stage! 3 "Homebrew" verify-homebrew!)
  (stage! 4 "Command-line dependencies" install-dependencies!)
  (stage! 5 "Ghostty" install-ghostty!)
  (stage! 6 "Oh My Zsh" install-oh-my-zsh!)
  (stage! 7 "Pinned Vim plugins" update-submodules!)
  (stage! 8 "Configuration links" link-configs!)
  (stage! 9 "Validation" validate!)

  (print-timings)
  (println)
  (println "[##################################################] 100%")
  (println "╭─ SETUP COMPLETE")
  (println "│  Your macOS dot-files environment is ready.")
  (println "╰─ Next: restart the terminal or run source ~/.zshrc")
  (catch Exception error
    (when-let [temporary @oh-my-zsh-temp]
      (when (bootstrap.lib.common/path-present? temporary)
        (fs/delete-tree temporary)))
    (bootstrap.lib.common/failure (.getMessage error))
    (System/exit 1)))
