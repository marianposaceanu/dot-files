(require '[babashka.classpath :as classpath]
         '[babashka.fs :as fs])

(def ^:private repo-root (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))
(classpath/add-classpath repo-root)
(require '[bootstrap.lib.common :as common]
         '[bootstrap.lib.site :as site]
         '[clojure.string :as str])

(defn- render-source [{:keys [output-dir template hashes]} source]
  (let [tutorial (site/parse-tutorial (fs/file-name source) (slurp (str source)))
        output (fs/path output-dir (str (site/slug (fs/strip-ext (fs/file-name source))) ".html"))]
    {:output output
     :relative (str (fs/relativize repo-root output))
     :html (site/page template hashes tutorial)}))

(defn- current-page? [{:keys [output html]}]
  (and (fs/regular-file? output) (= (slurp (str output)) html)))

(defn -main [& args]
  (when-not (contains? #{[] ["--check"]} (vec args))
    (common/usage-error! "Usage: bb bootstrap/site/build_tutorial_pages.clj [--check]"))
  (let [check? (= ["--check"] (vec args))
        output-dir (fs/path repo-root "docs")
        sources (sort (fs/glob (fs/path repo-root "tutorials") "*.md"))
        template (slurp (str (fs/path repo-root "bootstrap/site/tutorial_page.html")))
        hashes (into {} (map (fn [[key asset]] [key (site/asset-hash (fs/path output-dir "assets" asset))]))
                     [["css-hash" "site.css"] ["dotfiles-hash" "dotfiles.css"] ["js-hash" "site.js"]])]
    (site/ensure! (seq sources) (str "No Markdown tutorials found in " (fs/path repo-root "tutorials")))
    (when-not check? (fs/create-dirs output-dir))
    (let [pages (mapv (partial render-source {:output-dir output-dir :template template :hashes hashes}) sources)]
      (if check?
        (let [stale (into [] (comp (remove current-page?) (map :relative)) pages)]
          (site/ensure! (empty? stale) (str "Generated tutorial pages are stale:\n" (str/join "\n" (map #(str "  " %) stale))))
          (println (str "Generated tutorial pages match " (count sources) " Markdown sources.")))
        (doseq [{:keys [output relative html]} pages]
          (spit (str output) html)
          (println "built" relative))))))

(common/run-script! -main *command-line-args*)
