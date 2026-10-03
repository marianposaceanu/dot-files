(require '[babashka.classpath :as classpath]
         '[babashka.fs :as fs])

(def ^:private repo-root
  (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))

(classpath/add-classpath repo-root)
(require '[bootstrap.lib.common :as common]
         '[bootstrap.lib.rvm :as rvm])

(defn -main [& args]
  (when-not (contains? #{[] ["--check"]} (vec args))
    (common/usage-error! "Usage: bb bootstrap/setup/install_rvm.clj [--check]"))
  (let [config (rvm/read-config (fs/path repo-root "rvm/config.edn"))]
    (common/start-panel "RVM RUBIES" "Checking repository Ruby requirements")
    (if (seq args)
      (let [results (rvm/status config)]
        (doseq [{:keys [status message]} results]
          (if (= :ok status) (common/success message) (common/warning message)))
        (when (some #(= :warn (:status %)) results)
          (throw (ex-info "RVM requirements are not satisfied." {}))))
      (rvm/install! config))
    (println)
    (common/success-panel "RVM COMPLETE" "Repository Ruby requirements are satisfied.")))

(common/run-script! -main *command-line-args*)
