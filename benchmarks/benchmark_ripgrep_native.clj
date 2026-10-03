(ns benchmarks.benchmark-ripgrep-native
  (:require [babashka.fs :as fs]
            [benchmarks.lib.binary :as binary]
            [benchmarks.lib.core :as b]
            [benchmarks.lib.corpus :as corpus]
            [clojure.string :as str]))

(defn cases [root]
  (let [large (b/path root "large") small (b/path root "small")
        literal "NEEDLE_native_rg_7d3f91a2"]
    (into (mapv (fn [threads]
                  {:name (str "literal, " (case threads "1" "one thread" "2" "two threads" "4" "four threads" "8" "eight threads" nil "default threads"))
                   :root large :pattern literal :args (cond-> [] threads (into ["--threads" threads]))})
                ["1" "2" "4" "8" nil])
          [{:name "regex, one thread" :root large :pattern "error_code=[A-Z]{3}[0-9]{4} path=/api/v[0-9]+/[[:alnum:]_-]+" :args ["--threads" "1"]}
           {:name "Unicode regex, one thread" :root large :pattern "(?i)résumé\\s+naïve" :args ["--threads" "1"]}
           {:name "PCRE2 lookaround, one thread" :root large :pattern "(?<=request_id=)[a-f0-9]{16}(?=;)" :args ["--threads" "1" "--pcre2"]}
           {:name "5,000-file traversal" :root small :args ["--files"]}])))

(defn command [binary {:keys [root pattern args]}]
  (into [binary "--no-config" "--no-ignore" "--no-messages"]
        (concat args (when pattern ["--count" pattern]) [root])))

(defn expected-output [{:keys [root pattern]}]
  (let [files (sort (filter fs/regular-file? (fs/glob root "**")))
        regex (when pattern (re-pattern (str/replace pattern "[[:alnum:]_-]" "[A-Za-z0-9_-]")))]
    (if regex
      (keep (fn [file]
              (let [matches (count (filter #(re-find regex %) (str/split-lines (slurp (str file)))))]
                (when (pos? matches) (str file ":" matches)))) files)
      (map str files))))

(defn validate! [binaries case]
  (let [expected (vec (sort (expected-output case)))]
    (when (empty? expected) (b/fail! "Benchmark corpus has no expected output" {:case case}))
    (doseq [binary binaries]
      (let [actual (sort (str/split-lines (b/output! (command binary case))))]
        (when-not (= expected actual)
          (b/fail! "Incorrect ripgrep benchmark output" {:binary binary :case case :expected expected :actual actual}))))))

(defn -main [& args]
  (if (= ["--help"] (vec args))
    (println "Usage: bb benchmarks/benchmark_ripgrep_native.clj [rg [label [comparison-rg comparison-label]]]")
    (let [options (binary/options args "rg" "RG_BENCH")
          root (corpus/ripgrep! (b/env "RG_BENCH_CORPUS" (b/path (fs/temp-dir) "ripgrep-native-benchmark-corpus-v1")))]
      (binary/report! options (cases root) command validate!))))

(b/run-cli! -main)
