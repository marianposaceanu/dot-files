(ns benchmarks.generate-vim-startup-chart
  (:require [benchmarks.lib.core :as b]
            [benchmarks.lib.startup :as startup]))

(def labels ["with_polyglot" "without_polyglot" "after_lazyload_opt_plugins" "lightline_only" "after_ack_removal_tabular_opt" "after_fugitive_opt"])

(defn -main [& args]
  (if (= ["--help"] (vec args))
    (println "Usage: bb benchmarks/generate_vim_startup_chart.clj")
    (do
      (when (seq args) (b/fail! "Unexpected chart arguments" {:args args}))
      (let [totals (mapv #(startup/archived-total (slurp (b/path b/bench-root (str "vim_startup_profile_" % ".txt")))) labels)
            best (apply min totals)]
        (b/number-option "Best archived total" best)
        (println "HISTORICAL SOURCING MAP (inclusive ms; nested times overlap)")
        (doseq [[label total] (map vector labels totals)]
          (let [filled (min 20 (max 1 (Math/round (* 2 (/ total best)))))]
            (println (format "%-34s %7.3f ms (%4.2fx vs best) [%s%s]" label total (/ total best)
                             (apply str (repeat filled "#")) (apply str (repeat (- 20 filled) "."))))))
        (println (format "Recorded inclusive totals: %.3f ms -> %.3f ms" (first totals) (last totals)))))))

(b/run-cli! -main)
