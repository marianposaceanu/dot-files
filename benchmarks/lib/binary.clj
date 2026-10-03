(ns benchmarks.lib.binary
  (:require [benchmarks.lib.core :as b]))

(defn options [args command prefix]
  (when (> (count args) 4) (b/fail! "Expected binary [label] [comparison-binary comparison-label]" {:args args}))
  (let [[binary label other other-label] args
        binary (b/executable (or binary command))]
    {:binaries (cond-> [binary] other (conj (b/executable other)))
     :labels (cond-> [(or label command)] other (conj (or other-label "comparison")))
     :repetitions (b/integer-option "Repetitions" (b/env (str prefix "_REPETITIONS") "9") 1)
     :warmups (b/integer-option "Warmups" (b/env (str prefix "_WARMUPS") "2") 0)}))

(defn report! [{:keys [binaries labels repetitions warmups]} cases command validate!]
  (doseq [case cases] (validate! binaries case))
  (binding [*out* *err*]
    (doseq [[binary label] (map vector binaries labels)] (println label ":" binary "(" (b/version binary) ")"))
    (println repetitions "repetitions after" warmups "warmups"))
  (if (= 1 (count binaries))
    (println "| Workload | Median | Minimum | Maximum |\n| --- | ---: | ---: | ---: |")
    (println (format "| Workload | %s | %s | %s change |\n| --- | ---: | ---: | ---: |" (first labels) (second labels) (first labels))))
  (doseq [case cases]
    (let [[left right] (b/sample-pair! #(b/timed! {} (command % case)) binaries warmups repetitions)
          {:keys [median minimum maximum]} (b/summary left)]
      (println
       (if right
         (let [baseline (b/median right)]
           (format "| %s | %.2f ms | %.2f ms | %+.1f%% |" (:name case) median baseline (* 100 (- (/ median baseline) 1))))
         (format "| %s | %.2f ms | %.2f ms | %.2f ms |" (:name case) median minimum maximum))))))
