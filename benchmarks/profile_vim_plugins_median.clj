(ns benchmarks.profile-vim-plugins-median
  (:require [benchmarks.lib.core :as b]
            [benchmarks.lib.startup :as startup]))

(defn -main [& args]
  (if (= ["--help"] (vec args))
    (println "Usage: RUNS=7 bb benchmarks/profile_vim_plugins_median.clj")
    (do
      (when (seq args) (b/fail! "Unexpected median-profile arguments" {:args args}))
      (let [runs (b/integer-option "RUNS" (b/env "RUNS" "7") 1)
            options (startup/options)
            samples (b/with-temp-dir
                      (fn [directory]
                        (mapv (fn [index]
                                (let [{:keys [files total]} (startup/profile! options (b/path directory (str index ".log")))
                                      self (reduce + 0.0 (map :self (startup/plugin-totals files)))]
                                  (println (format "Run %d: plugin_start_total=%.3fms total_startup=%.3fms" (inc index) self total))
                                  {:self self :total total})) (range runs))))]
        (println (format "\nMedian results (%d runs; plugin totals use self time):" runs))
        (println (format "- plugin_start_total_ms=%.3f" (b/median (map :self samples))))
        (println (format "- total_startup_ms=%.3f" (b/median (map :total samples))))))))

(b/run-cli! -main)
