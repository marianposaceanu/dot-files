(ns benchmarks.profile-vim-plugins
  (:require [babashka.fs :as fs]
            [benchmarks.lib.core :as b]
            [benchmarks.lib.startup :as startup]))

(defn -main [& args]
  (if (= ["--help"] (vec args))
    (println "Usage: bb benchmarks/profile_vim_plugins.clj (VIM_BIN and VIMRC_PATH override defaults)")
    (do
      (when (seq args) (b/fail! "Unexpected startup-profile arguments" {:args args}))
      (let [log (str (fs/create-temp-file {:prefix "vim-startuptime-" :suffix ".log"}))
            {:keys [files]} (startup/profile! (startup/options) log)]
        (println "Vim startup profile log:" log)
        (println "\nTop sourced files by self time (ms):")
        (doseq [{:keys [path self]} (take 20 (sort-by :self > files))] (println (format "%10.3f\t%s" self path)))
        (println "\nPlugin self-time totals under .vim/pack/bundles/start (ms):")
        (doseq [{:keys [name self files]} (startup/plugin-totals files)] (println (format "%10.3f\t%4d files\t%s" self files name)))
        (println "\nTip: run multiple times and compare medians for stability.")))))

(b/run-cli! -main)
