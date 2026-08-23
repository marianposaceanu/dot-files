(require '[babashka.fs :as fs])

(def repo-root
  (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))

(load-file (str (fs/path repo-root "bootstrap/lib/common.clj")))

(try
  (let [args (set *command-line-args*)]
    (when (or (not (every? #{"--summary"} args))
              (> (count *command-line-args*) 1))
      (binding [*out* *err*]
        (println "Usage: bb bootstrap/setup/link_configs.clj [--summary]"))
      (System/exit 2))

    (let [counts (bootstrap.lib.common/link-configs! repo-root)]
      (if (contains? args "--summary")
        (println (bootstrap.lib.common/summary counts))
        (bootstrap.lib.common/success
         (str "Configuration links: " (bootstrap.lib.common/summary counts))))))
  (catch Exception error
    (bootstrap.lib.common/abort! error)))
