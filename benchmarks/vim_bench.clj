(ns benchmarks.vim-bench
  (:require [babashka.fs :as fs]
            [babashka.process :as process]
            [benchmarks.lib.core :as b]
            [benchmarks.lib.corpus :as corpus]
            [clojure.string :as str]))

(def workloads
  [{:id "regex_scan" :description "Regex scan NFA (100k lines, no substitution)" :corpus :words :body "silent %substitute/\\w\\+//gn"}
   {:id "regex_replace" :description "Regex and replacement NFA (100k lines)" :corpus :words :body "silent %substitute/\\<\\w\\{3,8\\}\\>/[&]/g"}
   {:id "sort" :description "Buffer sort (100k lines)" :corpus :words :body "silent %sort"}
   {:id "vimscript_loop" :description "Vimscript while loop (500k iterations)" :corpus :words
    :body "let g:_x = 0\nlet g:_j = 0\nwhile g:_j < 500000\n  let g:_x += g:_j\n  let g:_j += 1\nendwhile"}
   {:id "regex_ruby" :description "Regex on Ruby source (complex alternation)" :corpus :ruby
    :body "silent %substitute/\\<\\(def\\|class\\|module\\|do\\|end\\|if\\|unless\\|rescue\\)\\>\\|:\\w\\+\\|\"[^\"]*\"\\|'[^']*'\\|#.*$\\|[0-9]\\+//gn"}])

(defn parse-options [args]
  (loop [[flag & more :as args] args options {:mode :full :runs 7 :label "bench"}]
    (if-not (seq args)
      options
      (case flag
        "--bench-only" (recur more (assoc options :mode :bench))
        "--runs" (recur (rest more) (assoc options :runs (b/integer-option flag (first more) 1)))
        "--label" (let [label (first more)]
                    (when-not (and label (re-matches #"[A-Za-z0-9_-]+" label)) (b/fail! "Invalid result label" {:label label}))
                    (recur (rest more) (assoc options :label label)))
        "--compare" (do
                      (when (< (count more) 2) (b/fail! "--compare requires two result files" {}))
                      (recur (drop 2 more) (assoc options :mode :compare :files (vec (take 2 more)))))
        (b/fail! "Unknown Vim benchmark argument" {:argument flag})))))

(defn workload-script [runs body]
  (str "let g:_times = []\nlet g:_i = 0\nwhile g:_i < " runs "\n"
       "  silent e!\n  let g:_t = reltime()\n"
       (str/join "\n" (map #(str "  " %) (str/split-lines body))) "\n"
       "  call add(g:_times, reltimefloat(reltime(g:_t)))\n  let g:_i += 1\nendwhile\n"
       "call writefile(map(copy(g:_times), 'string(v:val)'), $VIM_BENCH_TIMINGS)\nqa!\n"))

(defn timing-samples [text runs]
  (let [samples (mapv #(b/number-option "Vim timing" %) (str/split-lines text))]
    (when-not (= runs (count samples)) (b/fail! "Invalid or incomplete Vim timings" {:expected runs :actual (count samples)}))
    samples))

(defn run-workload! [binary files directory runs {:keys [id body corpus]}]
  (let [timings (b/path directory (str id ".times")) script (b/path directory (str id ".vim"))]
    (b/write! script (workload-script runs body))
    (b/capture! {:extra-env {"VIM_BENCH_TIMINGS" timings} :in nil}
                [binary "-Nu" "NONE" "-i" "NONE" "-n" "-Es" (get files corpus) "-S" script])
    (when-not (fs/regular-file? timings) (b/fail! "Vim did not produce timings" {:workload id}))
    (b/median (timing-samples (slurp timings) runs))))

(defn benchmark! [binary label runs]
  (let [files (corpus/vim! (b/env "VIM_BENCH_CORPUS" (b/path b/bench-root "corpus" "vim-v2")))
        version-output (b/output! [binary "--version"])
        metadata {"vim_binary" binary "vim_version" (first (str/split-lines version-output))
                  "compiled_by" (or (some-> (re-find #"Compiled by (.+)" version-output) second) "unknown")
                  "cflags" (or (some-> (re-find #"(?m)^.*clang -c.*-O[0-9Os].*$" (b/output! ["strings" binary])) first) "unknown")
                  "corpus_format" "vim-v2 (check hashes for reused/custom files)"
                  "words_sha256" (b/sha256 (:words files)) "ruby_sha256" (b/sha256 (:ruby files))
                  "runs" runs "timestamp" (b/now)}
        timings (b/with-temp-dir
                 (fn [directory]
                   (into {} (map (fn [{:keys [id description] :as workload}]
                                   (let [time (run-workload! binary files directory runs workload)]
                                     (println (format "%-48s %.6f s" description time))
                                     [id time])) workloads))))
        target (b/path (b/env "VIM_BENCH_RESULTS" (b/path b/bench-root "results")) (str label "_" (b/timestamp) ".txt"))
        report (str (apply str (map (fn [[key value]] (str key ": " value "\n")) (sort metadata)))
                    "---\n" (apply str (map #(format "%s: %.9g\n" (:id %) (get timings (:id %))) workloads)))]
    (b/atomic-write! target report)
    (println "Results:" target)
    target))

(defn read-result [file]
  (into {} (keep #(when-let [[_ key value] (re-matches #"([^:]+):\s*(.*)" %)] [key value]) (str/split-lines (slurp file)))))

(defn compare! [left right]
  (let [left (read-result left) right (read-result right)
        rows (mapv (fn [{:keys [id description]}]
                     [description (b/number-option id (get left id)) (b/number-option id (get right id))]) workloads)]
    (println "| Workload | Bottle (s) | Native (s) | Speedup |\n| --- | ---: | ---: | ---: |")
    (doseq [[description baseline candidate] rows]
      (println (format "| %s | %.6f | %.6f | %.2fx |" description baseline candidate (/ baseline candidate))))))

(defn full-comparison! [runs]
  (let [brew (b/executable "brew")]
    ;; This explicit mode preserves the legacy installation-changing workflow.
    @(apply process/process {:out :inherit :err :inherit} [brew "unpin" "vim"])
    (b/capture! [brew "uninstall" "--ignore-dependencies" "vim"])
    (b/capture! [brew "install" "homebrew/core/vim"])
    (let [prefix #(str/trim (b/output! [brew "--prefix" "vim"]))
          bottle (benchmark! (b/path (prefix) "bin" "vim") "bottle" runs)]
      (b/capture! ["bash" (b/path b/repo-root "bootstrap" "native" "compile_vim_native.sh")])
      (compare! bottle (benchmark! (b/path (prefix) "bin" "vim") "native" runs)))))

(defn -main [& args]
  (if (= ["--help"] (vec args))
    (println "Usage: bb benchmarks/vim_bench.clj [--bench-only] [--label LABEL] [--runs N] [--compare BOTTLE NATIVE]\nDefault mode reinstalls and rebuilds Homebrew Vim.")
    (let [{:keys [mode runs label files]} (parse-options args)]
      (case mode
        :compare (apply compare! files)
        :bench (benchmark! (b/executable (b/env "VIM_BIN" "vim")) label runs)
        :full (full-comparison! runs)))))

(b/run-cli! -main)
