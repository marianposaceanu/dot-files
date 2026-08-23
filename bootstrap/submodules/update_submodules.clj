(require '[babashka.fs :as fs])

(def repo-root
  (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))

(load-file (str (fs/path repo-root "bootstrap/lib/common.clj")))

(try
  (let [arg (first *command-line-args*)]
    (when (or (> (count *command-line-args*) 1)
              (not (contains? #{nil "--remote" "-h" "--help"} arg)))
      (binding [*out* *err*]
        (println "Usage: bb bootstrap/submodules/update_submodules.clj [--remote]"))
      (System/exit 2))
    (when (contains? #{"-h" "--help"} arg)
      (println "Usage: bb bootstrap/submodules/update_submodules.clj [--remote]")
      (System/exit 0))

    (bootstrap.lib.common/start-panel
     "VIM PLUGIN SUBMODULES"
     (if (= "--remote" arg)
       "Updating from configured remotes"
       "Restoring repository-pinned revisions"))
    (if (= "--remote" arg)
      (bootstrap.lib.common/info "Updating submodules from configured remotes...")
      (bootstrap.lib.common/info "Updating submodules to repository-pinned revisions..."))
    (bootstrap.lib.common/run!
     ["git" "-C" repo-root "submodule" "--quiet" "sync" "--recursive"])
    (bootstrap.lib.common/run!
     (cond-> ["git" "-C" repo-root "submodule" "--quiet" "update" "--init"]
       (= "--remote" arg) (conj "--remote")
       true (conj "--recursive")))
    (println)
    (bootstrap.lib.common/success-panel
     "SUBMODULES COMPLETE"
     "Submodules are up to date."))
  (catch Exception error
    (bootstrap.lib.common/abort! error)))
