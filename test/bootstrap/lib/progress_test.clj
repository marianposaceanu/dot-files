(ns bootstrap.lib.progress-test
  (:require [babashka.fs :as fs]
            [babashka.process :as process]
            [bootstrap.lib.progress :as progress]
            [clojure.edn :as edn]
            [clojure.string :as str]
            [clojure.test :refer [deftest is testing]]
            [test.support :as support]))

(defn- child-command [exit-code]
  [support/bb "-cp" support/repo-root "-e"
   (pr-str
    `(do
       (require '~'[bootstrap.lib.progress :as progress])
       (println (System/getenv "DOT_FILES_PROGRESS_FILE"))
       (~'progress/report! 1 2)
       (Thread/sleep 200)
       (when (zero? ~exit-code) (~'progress/report! 2 2))
       (binding [*out* *err*] (println "child diagnostic"))
       (System/exit ~exit-code)))])

(deftest run-reporting-test
  (testing "Successful children report milestones, preserve output, and remove temporary files"
    (let [milestones (atom [])
          result (progress/run-reporting!
                  {:out :string :err :string} (child-command 0)
                  #(swap! milestones conj [%1 %2]))
          path (str/trim (:out result))]
      (is (= [[1 2] [2 2]] @milestones))
      (is (= "child diagnostic\n" (:err result)))
      (is (not (fs/exists? (fs/parent path))))))
  (testing "Failed children retain their exit status and diagnostics and remove temporary files"
    (let [milestones (atom [])
          error (try
                   (progress/run-reporting!
                    {:out :string :err :string} (child-command 7)
                    #(swap! milestones conj [%1 %2]))
                   (catch clojure.lang.ExceptionInfo error
                     error))
          result (ex-data error)
          path (some-> result :out str/trim)]
      (is (instance? clojure.lang.ExceptionInfo error))
      (is (= 7 (:exit result)))
      (is (= [[1 2]] @milestones))
      (is (= "child diagnostic\n" (:err result)))
      (is (and path (not (fs/exists? (fs/parent path))))))))

(deftest reports-stay-readable-during-replacement-test
  (let [directory (fs/create-temp-dir {:prefix "dot-files-progress-test-"})
        path (str (fs/path directory "progress.edn"))
        child (process/process
               {:out :string :err :string :extra-env {"DOT_FILES_PROGRESS_FILE" path}}
               support/bb "-cp" support/repo-root "-e"
               "(require '[bootstrap.lib.progress :as progress]) (dotimes [i 5000] (progress/report! (inc i) 5000))")
        errors (atom [])]
    (try
      (while (nil? (deref child 0 nil))
        (when (fs/exists? path)
          (try
            (edn/read-string (slurp path))
            (catch Exception error
              (swap! errors conj (.getMessage error))))))
      (is (zero? (:exit @child)) (:err @child))
      (is (empty? @errors) (str "Progress reads failed: " (take 3 @errors)))
      (is (= [5000 5000] (edn/read-string (slurp path))))
      (finally
        (fs/delete-tree directory)))))
