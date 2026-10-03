(ns benchmarks.benchmark-ctags-native
  (:require [benchmarks.lib.binary :as binary]
            [benchmarks.lib.core :as b]
            [benchmarks.lib.corpus :as corpus]
            [cheshire.core :as json]
            [clojure.string :as str]))

(defn cases [root]
  (mapv (fn [[name languages directory]]
          {:name name :args [(str "--languages=" languages) (b/path root directory)]})
        [["C parser" "C" "c"] ["Ruby parser" "Ruby" "ruby"]
         ["JSON and YAML parsers" "JSON,Yaml" "data"] ["representative mixed parsers" "C,Ruby,JSON,Yaml" "mixed"]]))

(defn command [binary {:keys [args]}]
  (into [binary "--options=NONE" "--sort=no" "-f" "/dev/null" "-R"] args))

(defn validate! [binaries {:keys [args] :as case}]
  (let [outputs (mapv #(b/capture! (into [% "--options=NONE" "--sort=yes" "--output-format=json" "-f" "-" "-R"] args)) binaries)]
    (doseq [output outputs]
      (when-not (some #(= "tag" (:_type (json/parse-string % true))) (str/split-lines (:out output)))
        (b/fail! "Ctags produced no tags for the workload" {:case case})))
    (when-not (apply = (map #(select-keys % [:out :err]) outputs))
      (b/fail! "Non-equivalent deterministic Ctags output" {:case case}))))

(defn -main [& args]
  (if (= ["--help"] (vec args))
    (println "Usage: bb benchmarks/benchmark_ctags_native.clj [ctags [label [comparison-ctags comparison-label]]]")
    (let [options (binary/options args "ctags" "CTAGS_BENCH")]
      (b/with-temp-dir #(binary/report! options (cases (corpus/ctags! %)) command validate!)))))

(b/run-cli! -main)
