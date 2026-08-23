(require '[babashka.fs :as fs]
         '[clojure.string :as str])

(def repo-root
  (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))

(load-file (str (fs/path repo-root "bootstrap/lib/common.clj")))

(when (seq *command-line-args*)
  (binding [*out* *err*]
    (println "Usage: bb bootstrap/checks/doctor.clj"))
  (System/exit 2))

(def warnings (atom 0))

(defn warn [message]
  (swap! warnings inc)
  (bootstrap.lib.common/warning message))

(defn ok [message]
  (bootstrap.lib.common/success message))

(defn check-symlink [{:keys [source target label]}]
  (cond
    (not (bootstrap.lib.common/path-present? target))
    (warn (str label " is missing (" target ")"))

    (not (fs/sym-link? target))
    (warn (str label " exists but is not a symlink (" target ")"))

    (bootstrap.lib.common/correct-link? source target)
    (ok (str label " -> " source))

    :else
    (warn (str label " points to '" (fs/read-link target)
               "' (expected '" source "')"))))

(defn check-symlink-capability []
  (let [directory (fs/create-temp-dir {:prefix "dot-files-doctor-"})
        target (fs/path directory "target")
        link (fs/path directory "link")]
    (try
      (fs/create-file target)
      (fs/create-sym-link link target)
      (if (fs/sym-link? link)
        (ok "filesystem supports symlink creation")
        (warn "unable to create a symlink on this filesystem/session"))
      (catch Exception _
        (warn "unable to create a symlink on this filesystem/session"))
      (finally
        (fs/delete-tree directory)))))

(defn brew-formulas [brewfile]
  (map second (re-seq #"(?m)^brew\s+\"([^\"]+)\"" (slurp brewfile))))

(defn successful? [command]
  (zero? (:exit (bootstrap.lib.common/result command))))

(defn active-vim-is-custom-brew-build? [brew]
  (try
    (let [active-vim (bootstrap.lib.common/command-path "vim")
          brew-prefix (bootstrap.lib.common/capture [brew "--prefix" "vim"])
          brew-vim (str (fs/path brew-prefix "bin/vim"))]
      (and active-vim
           (fs/executable? active-vim)
           (fs/executable? brew-vim)
           (java.nio.file.Files/isSameFile (fs/path active-vim) (fs/path brew-vim))
           (some #(re-matches #"Compiled by native-apple-m[0-9]+" %)
                 (str/split-lines
                  (bootstrap.lib.common/capture [active-vim "--version"])))))
    (catch Exception _ false)))

(defn brew-pinned? [brew formula]
  (contains? (set (str/split-lines
                   (:out (bootstrap.lib.common/result
                          [brew "list" "--pinned"]))))
             formula))

(defn check-brew-deps []
  (let [brew (bootstrap.lib.common/command-path "brew")
        brewfile (str (fs/path repo-root "Brewfile"))]
    (cond
      (nil? brew)
      (warn "Homebrew is not installed or not in PATH; skipping Brewfile checks")

      (not (fs/regular-file? brewfile))
      (warn (str "Brewfile not found at " brewfile))

      :else
      (let [formulas (vec (brew-formulas brewfile))]
        (if (empty? formulas)
          (warn "Brewfile has no brew formula entries")
          (let [missing (vec (remove #(successful? [brew "list" "--versions" %])
                                     formulas))
                outdated (->> (str/split-lines
                               (:out (bootstrap.lib.common/result
                                      [brew "outdated" "--formula" "--quiet"])))
                              (remove str/blank?)
                              set)
                outdated-formulas (vec (filter outdated formulas))]
            (doseq [formula missing]
              (warn (str "missing brew formula: " formula)))
            (when (empty? missing)
              (ok "all Brewfile formulas are installed"))

            (doseq [formula outdated-formulas]
              (if (and (= "vim" formula)
                       (active-vim-is-custom-brew-build? brew))
                (if (brew-pinned? brew "vim")
                  (bootstrap.lib.common/info
                   "Homebrew has a Vim update, but the active Vim is custom compiled and pinned; rebuild it when ready")
                  (warn "Homebrew has a Vim update and the active Vim is custom compiled but not pinned; run brew pin vim or rebuild it"))
                (warn (str "outdated brew formula: " formula))))
            (when (empty? outdated-formulas)
              (ok "no outdated Brewfile formulas"))))))))

(try
  (bootstrap.lib.common/start-panel
   "DOT-FILES :: DOCTOR"
   "Inspecting links, tools, and Homebrew dependencies")

  (bootstrap.lib.common/heading "CONFIGURATION LINKS")
  (check-symlink-capability)
  (doseq [spec (take 11 (bootstrap.lib.common/resolved-link-specs repo-root))]
    (check-symlink spec))

  (if (fs/regular-file? (fs/path (or (System/getenv "HOME")
                                     (System/getProperty "user.home"))
                                 ".oh-my-zsh/oh-my-zsh.sh"))
    (ok "Oh My Zsh is installed")
    (warn "Oh My Zsh is not installed (~/.oh-my-zsh missing)"))

  (if (bootstrap.lib.common/command-path "mextdisplay")
    (ok "mextdisplay is installed")
    (warn "mextdisplay is not installed; run bb bootstrap/install_macos.clj"))

  (let [[bat-spec ghostty-spec]
        (drop 11 (bootstrap.lib.common/resolved-link-specs repo-root))]
    (if (or (bootstrap.lib.common/command-path "bat")
            (bootstrap.lib.common/path-present? (:target bat-spec)))
      (check-symlink bat-spec)
      (bootstrap.lib.common/info "Skipping bat config symlink check (bat not detected)."))

    (if (or (bootstrap.lib.common/command-path "ghostty")
            (fs/executable? "/Applications/Ghostty.app/Contents/MacOS/ghostty"))
      (ok "Ghostty is installed")
      (warn "Ghostty is not installed; run bb bootstrap/install_macos.clj"))
    (check-symlink ghostty-spec))

  (bootstrap.lib.common/heading "HOMEBREW")
  (check-brew-deps)

  (println)
  (if (zero? @warnings)
    (bootstrap.lib.common/success-panel
     "DOCTOR COMPLETE"
     "No issues found.")
    (do
      (binding [*out* *err*]
        (bootstrap.lib.common/failure-panel
         "DOCTOR FOUND ISSUES"
         (format "%d warning%s require attention."
                 @warnings (if (= 1 @warnings) "" "s"))))
      (System/exit 1)))
  (catch Exception error
    (bootstrap.lib.common/abort! error)))
