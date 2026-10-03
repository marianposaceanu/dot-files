(require '[babashka.classpath :as classpath]
         '[babashka.fs :as fs])

(def ^:private repo-root (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))
(classpath/add-classpath repo-root)
(require '[bootstrap.lib.common :as common]
         '[bootstrap.lib.site :as site]
         '[cheshire.core :as json]
         '[clojure.data.xml :as xml]
         '[clojure.string :as str])

(defn- captures [pattern text]
  (mapv second (re-seq pattern text)))

(defn- schemas [html]
  (mapv json/parse-string (captures #"(?s)<script type=\"application/ld\+json\">(.*?)</script>" html)))

(defn- validate-page! [path]
  (let [html (slurp (str path))
        canonical (site/canonical-url path)
        metadata (second (re-find #"(?s)<ul class=\"meta\"[^>]*>(.*?)</ul>" html))
        ensure! (fn [condition message] (site/ensure! condition (str path ": " message)))]
    (ensure! (= [canonical] (captures #"<link rel=\"canonical\" href=\"([^\"]+)\">" html))
             (str "expected canonical " canonical))
    (ensure! (not (str/includes? html "ecosystem-navigation")) "obsolete ecosystem navigation found")
    (ensure! (and metadata (= 1 (count (re-seq (re-pattern (java.util.regex.Pattern/quote site/byline)) metadata))))
             "missing or duplicate linked byline")
    (ensure! (str/includes? html "<meta name=\"author\" content=\"Marian Posăceanu\">") "author meta tag disagrees")
    (when-not (= "index.html" (fs/file-name path))
      (let [article-schemas (schemas html)
            type (if (= "m4-low-power-mode-performance.html" (fs/file-name path)) "Article" "TechArticle")
            headline (second (re-find #"(?s)<h1 id=\"page-title\">(.*?)</h1>" html))
            description (second (re-find #"<meta name=\"description\" content=\"([^\"]*)\">" html))
            dates (captures #"<time class=\"article-date\" datetime=\"([^\"]+)\">" html)]
        (ensure! (= 1 (count article-schemas)) "expected one article schema")
        (ensure! (and (seq headline) (seq description) (= 1 (count dates)))
                 "missing page title, description or published date")
        (ensure! (= (first article-schemas)
                     (site/article-schema {:type type :canonical canonical
                                           :title (site/unescape-html headline)
                                           :description (site/unescape-html description)
                                           :published (first dates)}))
                 "article schema disagrees with visible page metadata")))))

(defn -main [& args]
  (when (seq args) (common/usage-error! "Usage: bb bootstrap/site/validate_site.clj"))
  (let [docs (fs/path repo-root "docs")
        pages (->> (fs/glob docs "*.html")
                   (remove #(= "vim-performance.html" (fs/file-name %))) sort vec)]
    (site/ensure! (seq pages) "No published pages found")
    (doseq [page pages] (validate-page! page))
    (let [homepage-schemas (schemas (slurp (str (fs/path docs "index.html"))))
          sitemap (xml/parse-str (slurp (str (fs/path docs "sitemap.xml"))))
          urls (->> (tree-seq map? :content sitemap)
                    (filter #(and (map? %) (= "loc" (name (:tag %)))))
                    (mapv #(apply str (:content %))))]
      (site/ensure! (= 1 (count (filter #{site/website} homepage-schemas)))
                    "Homepage WebSite identity is missing or duplicated")
      (site/ensure! (= 1 (count homepage-schemas)) "Homepage has unexpected schemas")
      (site/ensure! (= urls (mapv site/canonical-url pages)) "Sitemap does not match canonical page inventory")
      (site/ensure! (= urls (vec (distinct urls))) "Sitemap contains duplicate URLs"))
    (println (str "Published site contract passed for " (count pages) " pages."))))

(common/run-script! -main *command-line-args*)
