(require '[babashka.classpath :as classpath]
         '[babashka.fs :as fs])
(classpath/add-classpath (str (fs/parent (fs/parent (fs/canonicalize *file*)))))
(ns progress-test
  (:require [babashka.fs :as fs]
            [bootstrap.lib.common :as common]
            [bootstrap.lib.progress :as progress]
            [clojure.string :as str]
            [clojure.test :as test :refer [deftest is]]))

(defn child-command [exit]
  [(common/command-path "bb") "-cp" (str (fs/canonicalize ".")) "-e"
   (pr-str
    `(do
       (require '~'[bootstrap.lib.progress :as progress])
       (println (System/getenv "DOT_FILES_PROGRESS_FILE"))
       (~'progress/report! 1 2)
       (Thread/sleep 200)
       (when (zero? ~exit) (~'progress/report! 2 2))
       (binding [*out* *err*] (println "child diagnostic"))
       (System/exit ~exit)))])

(deftest child-milestones-preserve-output-and-clean-up
  (let [milestones (atom [])
        result (progress/run-reporting!
                {:out :string :err :string} (child-command 0)
                #(swap! milestones conj [%1 %2]))
        path (str/trim (:out result))]
    (is (= [[1 2] [2 2]] @milestones))
    (is (= "child diagnostic\n" (:err result)))
    (is (not (fs/exists? (fs/parent path))))))

(deftest child-failures-remain-failures-and-clean-up
  (let [milestones (atom [])
        error (try
                (progress/run-reporting!
                 {:out :string :err :string} (child-command 7)
                 #(swap! milestones conj [%1 %2]))
                nil
                (catch clojure.lang.ExceptionInfo error error))
        result (ex-data error)
        path (some-> result :out str/trim)]
    (is (= 7 (:exit result)))
    (is (= [[1 2]] @milestones))
    (is (= "child diagnostic\n" (:err result)))
    (is (and path (not (fs/exists? (fs/parent path)))))))

(let [{:keys [fail error]} (test/run-tests 'progress-test)]
  (when (pos? (+ fail error)) (System/exit 1)))
