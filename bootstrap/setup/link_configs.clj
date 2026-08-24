(require '[babashka.classpath :as classpath]
         '[babashka.fs :as fs])

(def ^:private repo-root
  (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))

(classpath/add-classpath repo-root)
(require '[bootstrap.lib.common :as common])

(def ^:private usage
  "Usage: bb bootstrap/setup/link_configs.clj [--summary]")

(defn- summary-only? [args]
  (case (vec args)
    [] false
    ["--summary"] true
    (common/usage-error! usage)))

(defn -main [& args]
  (if (summary-only? args)
    (println (common/summary (common/link-configs! repo-root)))
    (do
      (common/start-panel
       "CONFIGURATION LINKS"
       "Linking managed dot-files into your home directory")
      (let [counts (common/link-configs! repo-root)]
        (println)
        (common/success-panel "LINKS COMPLETE" (common/summary counts))))))

(common/run-script! -main *command-line-args*)
