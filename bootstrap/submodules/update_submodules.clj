(require '[babashka.classpath :as classpath]
         '[babashka.fs :as fs])

(def ^:private repo-root
  (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))

(classpath/add-classpath repo-root)
(require '[bootstrap.lib.common :as common])

(def ^:private usage
  "Usage: bb bootstrap/submodules/update_submodules.clj [--remote]")

(defn- parse-mode [args]
  (case (vec args)
    [] :pinned
    ["--remote"] :remote
    (["-h"] ["--help"]) (do (println usage) (System/exit 0))
    (common/usage-error! usage)))

(defn- update-command [mode]
  (cond-> ["git" "-C" repo-root "submodule" "--quiet" "update" "--init"]
    (= :remote mode) (conj "--remote")
    true (conj "--recursive")))

(defn -main [& args]
  (let [mode (parse-mode args)
        remote? (= :remote mode)]
    (common/start-panel
     "VIM PLUGIN SUBMODULES"
     (if remote?
       "Updating from configured remotes"
       "Restoring repository-pinned revisions"))

    (common/info
     (if remote?
       "Updating submodules from configured remotes..."
       "Updating submodules to repository-pinned revisions..."))
    (common/run!
     ["git" "-C" repo-root "submodule" "--quiet" "sync" "--recursive"])
    (common/run! (update-command mode))

    (println)
    (common/success-panel
     "SUBMODULES COMPLETE"
     "Submodules are up to date.")))

(common/run-script! -main *command-line-args*)
