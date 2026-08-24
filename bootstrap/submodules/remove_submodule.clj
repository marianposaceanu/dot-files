(require '[babashka.fs :as fs]
         '[clojure.string :as str])

(def repo-root
  (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))

(load-file (str (fs/path repo-root "bootstrap/lib/common.clj")))

(def usage
  "Usage: bb bootstrap/submodules/remove_submodule.clj <submodule-path>")

(defn configured-submodules [gitmodules]
  (let [{:keys [exit out err]}
        (bootstrap.lib.common/result
         ["git" "-C" repo-root "config" "-f" (str gitmodules)
          "--get-regexp" "^submodule\\..*\\.path$"])]
    (cond
      (zero? exit)
      (mapv (fn [line]
              (let [[key path] (str/split line #"\s+" 2)]
                {:path path
                 :section (str/replace key #"\.path$" "")}))
            (str/split-lines (str/trim out)))

      (= 1 exit) []

      :else
      (throw (ex-info (or (some-> err str/trim not-empty)
                          "Unable to read .gitmodules")
                      {:exit exit})))))

(defn metadata-path [submodule-path]
  (let [git-path (bootstrap.lib.common/capture
                  ["git" "-C" repo-root "rev-parse" "--git-path" "modules"])
        raw-root (fs/path git-path)
        root (-> (if (.isAbsolute raw-root)
                   raw-root
                   (.resolve (fs/path repo-root) raw-root))
                 .toAbsolutePath
                 .normalize)
        target (-> (.resolve root submodule-path) .normalize)]
    (when-not (.startsWith target root)
      (throw (ex-info "Submodule metadata path would escape Git's modules directory"
                      {:path submodule-path})))
    target))

(let [arg (first *command-line-args*)]
  (when (contains? #{"-h" "--help"} arg)
    (println usage)
    (System/exit 0))
  (when (not= 1 (count *command-line-args*))
    (binding [*out* *err*]
      (println usage))
    (System/exit 2)))

(try
  (let [submodule-path (first *command-line-args*)
        gitmodules (fs/path repo-root ".gitmodules")
        matches (filterv #(= submodule-path (:path %))
                         (if (bootstrap.lib.common/path-present? gitmodules)
                           (configured-submodules gitmodules)
                           (throw (ex-info ".gitmodules was not found at the repository root"
                                           {}))))]
    (when (empty? matches)
      (throw (ex-info (format "Submodule path '%s' does not exist in .gitmodules"
                              submodule-path)
                      {:path submodule-path})))
    (when (> (count matches) 1)
      (throw (ex-info (format "Multiple submodule sections match '%s': %s"
                              submodule-path
                              (str/join ", " (map :section matches)))
                      {:path submodule-path})))

    (let [section (:section (first matches))]
      (bootstrap.lib.common/start-panel
       "REMOVE SUBMODULE"
       (format "Removing '%s' from '%s'" section submodule-path))

      (bootstrap.lib.common/result
       ["git" "-C" repo-root "submodule" "deinit" "-f" "--" submodule-path])
      (bootstrap.lib.common/run!
       ["git" "-C" repo-root "rm" "-f" "--" submodule-path])

      (when (bootstrap.lib.common/path-present? gitmodules)
        (when (zero? (:exit (bootstrap.lib.common/result
                             ["git" "-C" repo-root "config" "-f" (str gitmodules)
                              "--get" (str section ".path")])))
          (bootstrap.lib.common/run!
           ["git" "-C" repo-root "config" "-f" (str gitmodules)
            "--remove-section" section]))
        (bootstrap.lib.common/run!
         ["git" "-C" repo-root "add" "--" (str gitmodules)]))

      (bootstrap.lib.common/result
       ["git" "-C" repo-root "config" "--remove-section" section])

      (let [metadata (metadata-path submodule-path)]
        (when (bootstrap.lib.common/path-present? metadata)
          (fs/delete-tree metadata)))

      (println)
      (bootstrap.lib.common/success-panel
       "SUBMODULE REMOVED"
       (format "'%s' was removed successfully." section))))
  (catch Exception error
    (bootstrap.lib.common/abort! error)))
