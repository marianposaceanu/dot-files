(require '[babashka.classpath :as classpath]
         '[babashka.fs :as fs]
         '[clojure.string :as str])

(def ^:private repo-root
  (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))

(classpath/add-classpath repo-root)
(require '[bootstrap.lib.common :as common])

(def ^:private usage "Usage: bb bootstrap/checks/doctor.clj")

;; Checks return result maps ({:status :ok/:warn/:info :message ...}) or
;; sequences of them; report! prints a section and returns its warning count.

(defn- ok [message]
  {:status :ok :message message})

(defn- warn [message]
  {:status :warn :message message})

(defn- note [message]
  {:status :info :message message})

(defn- report! [results]
  (let [results (vec results)]
    (doseq [{:keys [status message]} results]
      (case status
        :ok (common/success message)
        :warn (common/warning message)
        :info (common/info message)))
    (count (filterv #(= :warn (:status %)) results))))

(defn- link-spec [managed-links label]
  (or (some #(when (= label (:label %)) %) managed-links)
      (throw (ex-info (str "Managed link spec is missing: " label) {}))))

(defn- check-symlink [{:keys [source target label]}]
  (cond
    (not (common/path-present? target))
    (warn (str label " is missing (" target ")"))

    (not (fs/sym-link? target))
    (warn (str label " exists but is not a symlink (" target ")"))

    (common/correct-link? source target)
    (ok (str label " -> " source))

    :else
    (warn (str label " points to '" (fs/read-link target)
               "' (expected '" source "')"))))

(defn- check-symlink-capability []
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

(defn- check-oh-my-zsh []
  (let [home (or (System/getenv "HOME") (System/getProperty "user.home"))]
    (if (fs/regular-file? (fs/path home ".oh-my-zsh/oh-my-zsh.sh"))
      (ok "Oh My Zsh is installed")
      (warn "Oh My Zsh is not installed (~/.oh-my-zsh missing)"))))

(defn- check-mextdisplay []
  (if (common/command-path "mextdisplay")
    (ok "mextdisplay is installed")
    (warn "mextdisplay is not installed; run bb bootstrap/install_macos.clj")))

(defn- check-bat [bat-spec]
  (if (or (common/command-path "bat")
          (common/path-present? (:target bat-spec)))
    (check-symlink bat-spec)
    (note "Skipping bat config symlink check (bat not detected).")))

(defn- check-ghostty [ghostty-spec]
  [(if (or (common/command-path "ghostty")
           (fs/executable? "/Applications/Ghostty.app/Contents/MacOS/ghostty"))
     (ok "Ghostty is installed")
     (warn "Ghostty is not installed; run bb bootstrap/install_macos.clj"))
   (check-symlink ghostty-spec)])

(defn- link-results [managed-links]
  (let [bat-spec (link-spec managed-links "bat config")
        ghostty-spec (link-spec managed-links "Ghostty config")
        regular-links (remove #{bat-spec ghostty-spec} managed-links)]
    (concat [(check-symlink-capability)]
            (map check-symlink regular-links)
            [(check-oh-my-zsh)
             (check-mextdisplay)
             (check-bat bat-spec)]
            (check-ghostty ghostty-spec))))

(defn- brew-formulas [brewfile]
  (map second (re-seq #"(?m)^brew\s+\"([^\"]+)\"" (slurp brewfile))))

(defn- active-vim-is-custom-brew-build? [brew]
  (try
    (let [active-vim (common/command-path "vim")
          brew-prefix (common/capture [brew "--prefix" "vim"])
          brew-vim (str (fs/path brew-prefix "bin/vim"))]
      (and active-vim
           (fs/executable? active-vim)
           (fs/executable? brew-vim)
           (java.nio.file.Files/isSameFile (fs/path active-vim) (fs/path brew-vim))
           (some #(re-matches #"Compiled by native-apple-m[0-9]+" %)
                 (str/split-lines
                  (common/capture [active-vim "--version"])))))
    (catch Exception _ false)))

(defn- brew-pinned? [brew formula]
  (contains? (set (str/split-lines
                   (:out (common/result [brew "list" "--pinned"]))))
             formula))

(defn- check-outdated-formula [brew formula]
  (if (and (= "vim" formula)
           (active-vim-is-custom-brew-build? brew))
    (if (brew-pinned? brew "vim")
      (note "Homebrew has a Vim update, but the active Vim is custom compiled and pinned; rebuild it when ready")
      (warn "Homebrew has a Vim update and the active Vim is custom compiled but not pinned; run brew pin vim or rebuild it"))
    (warn (str "outdated brew formula: " formula))))

(defn- check-formulas [brew formulas]
  (let [missing (remove #(common/successful?
                          [brew "list" "--versions" %])
                        formulas)
        outdated (->> (:out (common/result
                             [brew "outdated" "--formula" "--quiet"]))
                      str/split-lines
                      (remove str/blank?)
                      set)
        outdated-formulas (filter outdated formulas)]
    (concat
     (map #(warn (str "missing brew formula: " %)) missing)
     (when (empty? missing)
       [(ok "all Brewfile formulas are installed")])
     (map #(check-outdated-formula brew %) outdated-formulas)
     (when (empty? outdated-formulas)
       [(ok "no outdated Brewfile formulas")]))))

(defn- brew-results []
  (let [brew (common/command-path "brew")
        brewfile (str (fs/path repo-root "Brewfile"))]
    (cond
      (nil? brew)
      [(warn "Homebrew is not installed or not in PATH; skipping Brewfile checks")]

      (not (fs/regular-file? brewfile))
      [(warn (str "Brewfile not found at " brewfile))]

      :else
      (let [formulas (brew-formulas brewfile)]
        (if (empty? formulas)
          [(warn "Brewfile has no brew formula entries")]
          (check-formulas brew formulas))))))

(defn- finish! [warnings]
  (println)
  (if (zero? warnings)
    (common/success-panel "DOCTOR COMPLETE" "No issues found.")
    (do
      (binding [*out* *err*]
        (common/failure-panel
         "DOCTOR FOUND ISSUES"
         (format "%d warning%s require attention."
                 warnings (if (= 1 warnings) "" "s"))))
      (System/exit 1))))

(defn -main [& args]
  (when (seq args)
    (common/usage-error! usage))

  (common/start-panel
   "DOT-FILES :: DOCTOR"
   "Inspecting links, tools, and Homebrew dependencies")

  (common/heading "CONFIGURATION LINKS")
  (let [link-warnings (report! (link-results (common/resolved-link-specs repo-root)))]
    (common/heading "HOMEBREW")
    (finish! (+ link-warnings (report! (brew-results))))))

(common/run-script! -main *command-line-args*)
