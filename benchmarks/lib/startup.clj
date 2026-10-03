(ns benchmarks.lib.startup
  (:require [babashka.fs :as fs]
            [benchmarks.lib.core :as b]
            [clojure.string :as str]))

(defn parse-log [text]
  {:files (into []
                (keep (fn [line]
                        (when-let [[_ inclusive self path] (re-find #"^\s*[\d.]+\s+([\d.]+)\s+([\d.]+):?\s+sourcing\s+(.+)$" line)]
                          {:path path
                           :inclusive (Double/parseDouble inclusive)
                           :self (Double/parseDouble self)})))
                (str/split-lines text))
   :total (or (some->> (str/split-lines text)
                      (keep #(second (re-find #"^\s*([\d]+\.[\d]+)\s" %))) last Double/parseDouble)
              (b/fail! "Startup log has no elapsed timestamps" {}))})

(defn plugin [path] (second (re-find #"/\.vim/pack/bundles/start/([^/]+)/" path)))

(defn plugin-totals [files]
  (->> files
       (keep #(when-let [name (plugin (:path %))] (assoc % :plugin name)))
       (group-by :plugin)
       (map (fn [[name files]] {:name name :self (reduce + (map :self files)) :files (count files)}))
       (sort-by :self >)))

(defn options []
  {:binary (b/executable (b/env "VIM_BIN" (or (some-> (fs/which "vim") str) "nvim")))
   :vimrc (b/env "VIMRC_PATH" (b/path b/repo-root ".vimrc"))})

(defn profile! [{:keys [binary vimrc]} log]
  (when-not (fs/regular-file? vimrc) (b/fail! "Vim config not found" {:vimrc vimrc}))
  (b/capture! [binary "-Nu" vimrc "-i" "NONE" "-n" "-es" "--startuptime" log "-c" "qall"])
  (parse-log (slurp log)))

(defn archived-total [text]
  (let [rows (-> text (str/split #"Plugin totals under \.vim/pack/bundles/start" 2) second)]
    (when-not rows (b/fail! "Archived startup profile has no inclusive plugin totals" {}))
    (reduce + 0.0 (keep #(some-> (re-find #"^\s*([\d.]+)\s+\d+ files" %) second Double/parseDouble)
                        (str/split-lines (first (str/split rows #"Tip:" 2)))))))
