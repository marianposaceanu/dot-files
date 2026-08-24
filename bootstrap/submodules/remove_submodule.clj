(require '[babashka.classpath :as classpath]
         '[babashka.fs :as fs]
         '[clojure.string :as str])

(def ^:private repo-root
  (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))

(classpath/add-classpath repo-root)
(require '[bootstrap.lib.common :as common])

(def ^:private usage
  "Usage: bb bootstrap/submodules/remove_submodule.clj <submodule-path>")

(defn- configured-submodules [gitmodules]
  (let [{:keys [exit out err]}
        (common/result
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

(defn- metadata-path [submodule-path]
  (let [git-path (common/capture
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

(defn- parse-submodule-path [args]
  (when (some #{"-h" "--help"} args)
    (println usage)
    (System/exit 0))
  (when-not (= 1 (count args))
    (common/usage-error! usage))
  (first args))

(defn- find-submodule! [gitmodules submodule-path]
  (when-not (common/path-present? gitmodules)
    (throw (ex-info ".gitmodules was not found at the repository root" {})))
  (let [matches (filterv #(= submodule-path (:path %))
                         (configured-submodules gitmodules))]
    (case (count matches)
      0 (throw (ex-info
                (format "Submodule path '%s' does not exist in .gitmodules"
                        submodule-path)
                {:path submodule-path}))
      1 (first matches)
      (throw (ex-info
              (format "Multiple submodule sections match '%s': %s"
                      submodule-path
                      (str/join ", " (map :section matches)))
              {:path submodule-path})))))

(defn- remove-section! [gitmodules section]
  (when (common/path-present? gitmodules)
    (when (common/successful?
           ["git" "-C" repo-root "config" "-f" (str gitmodules)
            "--get" (str section ".path")])
      (common/run!
       ["git" "-C" repo-root "config" "-f" (str gitmodules)
        "--remove-section" section]))
    (common/run! ["git" "-C" repo-root "add" "--" (str gitmodules)])))

(defn- remove-metadata! [submodule-path]
  (let [metadata (metadata-path submodule-path)]
    (when (common/path-present? metadata)
      (fs/delete-tree metadata))))

(defn- remove-submodule! [submodule-path]
  (let [gitmodules (fs/path repo-root ".gitmodules")
        {:keys [section]} (find-submodule! gitmodules submodule-path)]
    (common/start-panel
     "REMOVE SUBMODULE"
     (format "Removing '%s' from '%s'" section submodule-path))

    ;; Deinit and local config cleanup are intentionally tolerant: either may
    ;; already be absent while the tracked submodule still needs removal.
    (common/result
     ["git" "-C" repo-root "submodule" "deinit" "-f" "--" submodule-path])
    (common/run! ["git" "-C" repo-root "rm" "-f" "--" submodule-path])
    (remove-section! gitmodules section)
    (common/result ["git" "-C" repo-root "config" "--remove-section" section])
    (remove-metadata! submodule-path)

    (println)
    (common/success-panel
     "SUBMODULE REMOVED"
     (format "'%s' was removed successfully." section))))

(defn -main [& args]
  (remove-submodule! (parse-submodule-path args)))

(common/run-script! -main *command-line-args*)
