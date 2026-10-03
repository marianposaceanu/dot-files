(ns benchmarks.benchmark-git-native
  (:require [babashka.fs :as fs]
            [benchmarks.lib.core :as b]
            [clojure.string :as str]))

(def workloads
  [["status" "--short"] ["diff" "--stat" "HEAD"] ["grep" "-n" "deterministic" "HEAD"]
   ["grep" "-P" "request_id=\\d{8}[a-f]+" "HEAD"] ["log" "--all" "--oneline" "--decorate=no"]
   ["rev-list" "--all" "--objects"] ["fsck" "--no-progress"] ["commit-graph" "verify" "--shallow"]])

(defn parse-options [args]
  (let [[git & args] args
        _ (when-not git (b/fail! "Usage: benchmark_git_native.clj GIT [GIT2|pgo-training] [--warmups N] [--repetitions N]" {}))
        candidate (first args)
        training? (contains? #{"pgo-training" "--training"} candidate)
        other (when (and candidate (not training?) (not (str/starts-with? candidate "--"))) candidate)]
    (loop [args (if (or training? other) (rest args) args)
           options {:binaries (cond-> [(b/executable git)] other (conj (b/executable other)))
                    :training? training?
                    :warmups (b/integer-option "Warmups" (b/env "GIT_BENCH_WARMUPS" "2") 0)
                    :repetitions (b/integer-option "Repetitions" (b/env "GIT_BENCH_REPETITIONS" "7") 1)}]
      (if-let [[flag value & more] (seq args)]
        (case flag
          "--warmups" (recur more (assoc options :warmups (b/integer-option flag value 0)))
          "--repetitions" (recur more (assoc options :repetitions (b/integer-option flag value 1)))
          (b/fail! "Unknown Git benchmark argument" {:argument flag}))
        options))))

(defn command [binary repo args] (into [binary "-c" "core.hooksPath=/dev/null" "-C" repo] args))

(defn corpus! [binary root options]
  (let [repo (b/path root "repo") run! #(b/capture! options (command binary repo %))]
    (fs/create-dirs repo)
    (run! ["init" "-q" "--initial-branch=main"])
    (run! ["config" "user.name" "Benchmark"])
    (run! ["config" "user.email" "benchmark.invalid@example.invalid"])
    (doseq [revision (range 1 31)]
      (doseq [index (range 1 81)]
        (b/write! (b/path repo "src" (str "file-" index ".txt"))
                  (format "commit=%03d file=%03d deterministic needle_%d\nrequest_id=%08dabcdef\n" revision index (mod index 11) (+ (* revision 1000) index))))
      (b/write! (b/path repo "docs" "revision.md") (format "# Revision %03d\nThe deterministic benchmark corpus.\n" revision))
      (run! ["add" "--all"])
      (run! ["commit" "-q" "-m" (str "revision " revision)]))
    (run! ["branch" "side" "HEAD~10"])
    (run! ["commit-graph" "write" "--reachable"])
    (spit (b/path repo "src" "file-1.txt") "dirty deterministic line\n" :append true)
    repo))

(defn semantic-output! [options binary repo]
  (mapv #(select-keys (b/capture! options (command binary repo %)) [:out :err :exit]) workloads))

(defn cpu-seconds [text]
  (let [values (into {} (keep (fn [line]
                              (when-let [[_ field value] (re-matches #"(user|sys)\s+([\d.]+)" line)]
                                [field (Double/parseDouble value)])) (str/split-lines text)))]
    (when-not (= #{"user" "sys"} (set (keys values))) (b/fail! "Invalid CPU timing output" {:output text}))
    (+ (get values "user") (get values "sys"))))

(defn measure! [options binary repo]
  ;; Only this shell payload and Git processes are inside /usr/bin/time; no bb startup.
  (let [payload (str "set -e\n" (str/join "\n" (map #(str (str/join " " (map b/shell-quote (command binary repo %))) " >/dev/null") workloads)))
        result (b/capture! options ["/usr/bin/time" "-p" "/bin/bash" "-c" payload])]
    (cpu-seconds (:err result))))

(defn train! [options binary repo root repetitions]
  (dotimes [_ repetitions] (semantic-output! options binary repo))
  (let [copy (b/path root "train-copy")]
    (fs/copy-tree repo copy)
    (b/capture! options (command binary copy ["gc" "--quiet"]))
    (b/capture! options (command binary copy ["bundle" "create" (b/path root "train.bundle") "--all"]))
    (b/capture! options [binary "-c" "core.hooksPath=/dev/null" "-c" "protocol.file.allow=always" "clone" "-q" copy (b/path root "train-clone")])))

(defn -main [& args]
  (if (= ["--help"] (vec args))
    (println "Usage: bb benchmarks/benchmark_git_native.clj GIT [GIT2|pgo-training] [--warmups N] [--repetitions N]")
    (let [{:keys [binaries training? warmups repetitions]} (parse-options args)]
      (b/with-temp-dir
       (fn [root]
         (let [options {:extra-env {"XDG_CONFIG_HOME" (b/path root "xdg") "GIT_CONFIG_NOSYSTEM" "1" "GIT_CONFIG_GLOBAL" "/dev/null"
                                    "GIT_AUTHOR_DATE" "2026-01-01T00:00:00Z" "GIT_COMMITTER_DATE" "2026-01-01T00:00:00Z"
                                    "GIT_ATTR_NOSYSTEM" "1" "GIT_CONFIG_COUNT" "0"}}
               repo (corpus! (first binaries) root options)
               outputs (mapv #(semantic-output! options % repo) binaries)]
           (when-not (apply = outputs) (b/fail! "Git workload output differs" {}))
           (if training?
             (train! options (first binaries) repo root repetitions)
             (let [samples (b/sample-pair! #(measure! options % repo) binaries warmups repetitions)]
               (doseq [[binary samples] (map vector binaries samples)]
                 (println (format "%s\tmedian CPU seconds: %.6f" binary (b/median samples))))))))))))

(b/run-cli! -main)
