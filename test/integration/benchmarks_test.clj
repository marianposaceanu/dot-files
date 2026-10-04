(ns integration.benchmarks-test
  (:require [babashka.fs :as fs]
            [babashka.process :as process]
            [benchmarks.lib.core :as b]
            [cheshire.core :as json]
            [clojure.string :as str]
            [clojure.test :refer [deftest is testing use-fixtures]]
            [test.support :as support]))

(use-fixtures :each support/with-temp-dir)

(defn- wait-until [predicate]
  (let [deadline (+ (b/elapsed-ms) 2000)]
    (loop []
      (cond
        (predicate) true
        (>= (b/elapsed-ms) deadline) false
        :else (do (Thread/sleep 10) (recur))))))

(deftest process-tree-cleanup-test
  (testing "Cleanup terminates descendants that ignore graceful termination"
    (let [ready (support/path "child-ready")
          payload (str "/bin/bash -c 'trap \"\" TERM; touch \"$1\"; while :; do sleep 1; done' fixture "
                       (b/shell-quote ready) " & wait")
          child (process/process {:out :string :err :string} "/bin/bash" "-c" payload)]
      (try
        (is (wait-until #(fs/exists? ready)))
        (let [root (.toHandle (:proc child))
              handles (with-open [stream (.descendants root)] (vec (.toArray stream)))
              cleanup (future (b/stop-process! child))]
          (try
            (is (not= ::timeout (deref cleanup 4000 ::timeout)))
            (is (wait-until #(every? (fn [handle] (not (.isAlive handle))) handles)))
            (finally
              (doseq [handle (conj handles root)]
                (when (.isAlive handle) (.destroyForcibly handle)))
              (future-cancel cleanup))))
        (finally (b/stop-process! child))))))

(defn- executable! [name body]
  (support/executable! (support/path "bin" name) (str "#!/usr/bin/env bash\n" body)))

(defn- invoke! [script args env]
  (let [env (merge {"PATH" (str (support/path "bin") ":" (System/getenv "PATH"))
                   "TMPDIR" support/*temp-dir* "VIM_BENCH_CORPUS" (support/path "corpus") "VIM_BENCH_RESULTS" (support/path "results")} env)
        child (apply process/process {:dir support/*temp-dir* :extra-env env :out :string :err :string}
                     (into [support/bb "--config" (b/path support/repo-root "bb.edn") (b/path support/repo-root "benchmarks" script)] args))]
    (try
      (let [result (deref child 16000 ::timeout)]
        (when (= ::timeout result) (b/fail! "Benchmark fixture exceeded its timeout" {:script script}))
        result)
      (finally (b/stop-process! child)))))

(defn- vim-fixture! []
  (support/write-file! (support/path "corpus" "words_100k.txt") (apply str (repeat 20 "abcdef benchmark word\n")))
  (support/write-file! (support/path "corpus" "code_4k.rb") "class Example\n  def hello; 123; end\nend\n")
  (executable! "vim" "if [[ \"$1\" == --version ]]; then printf 'VIM fixture\\nCompiled by fixture\\n'; exit 0; fi\nif [[ \"${FAKE_VIM_EXIT:-0}\" != 0 ]]; then exit \"$FAKE_VIM_EXIT\"; fi\nprintf '%s\\n' \"${FAKE_VIM_DATA:-1.0}\" > \"$VIM_BENCH_TIMINGS\"\n"))

(deftest vim-workload-failure-test
  (testing "Failed Vim commands do not publish a completed results file"
    (let [binary (vim-fixture!) result (invoke! "vim_bench.clj" ["--bench-only" "--runs" "1"] {"VIM_BIN" binary "FAKE_VIM_EXIT" "17"})]
      (is (not (zero? (:exit result))))
      (is (not (fs/exists? (support/path "results")))))))

(deftest vim-median-and-validation-test
  (testing "Even medians are averaged and comparison rejects zero measurements"
    (let [binary (vim-fixture!)
          result (invoke! "vim_bench.clj" ["--bench-only" "--label" "fixture" "--runs" "2"] {"VIM_BIN" binary "FAKE_VIM_DATA" "1.0\n3.0"})
          files (fs/glob (support/path "results") "*.txt")]
      (is (zero? (:exit result)) (:err result))
      (is (= 1 (count files)))
      (when-let [file (first files)]
        (is (str/includes? (slurp (str file)) "regex_scan: 2.00000000"))
        (let [invalid (support/write-file! (support/path "invalid.txt") (str/replace (slurp (str file)) "regex_scan: 2.00000000" "regex_scan: 0"))
              comparison (invoke! "vim_bench.clj" ["--compare" (str file) invalid] {})]
          (is (not (zero? (:exit comparison)))))))))

(deftest real-vim-workloads-test
  (testing "All five workload scripts execute in real Vim without loading user configuration"
    (let [binary (b/executable "vim") _ (vim-fixture!)
          result (invoke! "vim_bench.clj" ["--bench-only" "--label" "smoke" "--runs" "1"] {"VIM_BIN" binary})]
      (is (zero? (:exit result)) (str (:out result) (:err result)))
      (is (= 1 (count (fs/glob (support/path "results") "smoke_*.txt")))))))

(defn- rg-corpus! []
  (support/write-file! (support/path "rg-corpus" ".complete") "fixture\n")
  (support/write-file! (support/path "rg-corpus" "large" "sample.log") "NEEDLE_native_rg_7d3f91a2 error_code=ERR2048 path=/api/v3/search-index request_id=0123456789abcdef; résumé naïve\n")
  (support/write-file! (support/path "rg-corpus" "small" "sample.txt") "ordinary content\n")
  (support/path "rg-corpus"))

(deftest invalid-ripgrep-output-test
  (testing "Empty successful output and no-match exits are rejected before measurement"
    (let [corpus (rg-corpus!)]
      (doseq [exit [0 1]]
        (let [binary (executable! "rg" (str "if [[ \"$1\" == --version ]]; then echo fixture; exit 0; fi\nexit " exit "\n"))
              result (invoke! "benchmark_ripgrep_native.clj" [binary] {"RG_BENCH_CORPUS" corpus "RG_BENCH_REPETITIONS" "1"})]
          (is (not (zero? (:exit result))))
          (is (not (str/includes? (:out result) "| Workload |"))))))))

(deftest real-ripgrep-comparison-test
  (testing "Matching-line oracles validate all nine workloads against a real binary"
    (let [binary (b/executable (if (fs/executable? "/opt/homebrew/bin/rg") "/opt/homebrew/bin/rg" "rg"))
          result (invoke! "benchmark_ripgrep_native.clj" [binary "one" binary "two"] {"RG_BENCH_CORPUS" (rg-corpus!) "RG_BENCH_REPETITIONS" "1"})]
      (is (zero? (:exit result)) (:err result))
      (is (str/includes? (:out result) "PCRE2 lookaround, one thread"))
      (is (= 9 (count (filter #(str/includes? % " ms |") (str/split-lines (:out result)))))))))

(deftest ctags-independent-samples-test
  (testing "Identical executable paths retain independent timed samples"
    (let [counter (support/path "counter")
          binary (executable! "ctags" (str "if [[ \"$1\" == --version ]]; then echo fixture; exit 0; fi\n"
                                           "if [[ \"$*\" == *--sort=no* ]]; then\ncount=0\n[[ ! -f " (b/shell-quote counter) " ]] || read -r count < " (b/shell-quote counter) "\n"
                                           "count=$((count + 1))\nprintf '%s\\n' \"$count\" > " (b/shell-quote counter) "\nif (( count % 2 )); then sleep 0.15; fi\n"
                                           "else printf '{\"_type\":\"tag\",\"name\":\"fixture\"}\\n'\nfi\n"))
          result (invoke! "benchmark_ctags_native.clj" [binary "one" binary "two"] {"CTAGS_BENCH_REPETITIONS" "1" "CTAGS_BENCH_WARMUPS" "0"})
          rows (filter #(str/includes? % " ms |") (str/split-lines (:out result)))]
      (is (zero? (:exit result)) (:err result))
      (is (= 4 (count rows)))
      (doseq [row rows]
        (let [[_ _ left right] (str/split row #"\|")]
          (is (> (- (Double/parseDouble (first (str/split (str/trim left) #"\s+")))
                    (Double/parseDouble (first (str/split (str/trim right) #"\s+")))) 50)))))))

(deftest browser-protocol-test
  (testing "Browser automation handles success, fragments, disconnects, stalls, and invalid scores"
    (let [chrome (executable! "chrome" (str "exec " (b/shell-quote support/bb) " --config " (b/shell-quote (b/path support/repo-root "bb.edn"))
                                          " -m test.fixtures.benchmarks.chrome \"$@\"\n"))]
      (doseq [[mode message] [["success" nil] ["fragmented" nil] ["disconnect" "connection closed"]
                              ["stall" "request timed out"] ["invalid" "Invalid Speedometer result"]
                              ["startup-stall" "Speedometer timed out"] ["http-stall" nil] ["connect-stall" nil]]]
        (testing mode
          (let [started (b/elapsed-ms)
                result (invoke! "low_power/speedometer_runner.clj" ["1"] {"CHROME_BIN" chrome "FAKE_CDP" mode
                                                               "SPEEDOMETER_TIMEOUT_MS" (if (= mode "startup-stall") "500" "3000")
                                                               "SPEEDOMETER_REQUEST_TIMEOUT_MS" "500"})]
            (if (contains? #{"success" "fragmented"} mode)
              (do (is (zero? (:exit result)) (:err result))
                  (when (zero? (:exit result)) (is (= "42" (:score (json/parse-string (:out result) true))))))
              (do (is (not (zero? (:exit result))))
                  (when message (is (str/includes? (str (:out result) (:err result)) message)))))
            (is (< (- (b/elapsed-ms) started) 6000) "Timeouts must bound the complete process")
            (is (empty? (fs/glob support/*temp-dir* "dot-files-benchmark-*")))))))))
