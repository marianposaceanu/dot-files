(require '[babashka.classpath :as classpath]
         '[babashka.fs :as fs])
(classpath/add-classpath (-> *file* fs/canonicalize fs/parent fs/parent str))
(ns site-test
  (:require [babashka.fs :as fs]
            [bootstrap.lib.site :as site]
            [clojure.string :as str]
            [clojure.test :refer [deftest is testing use-fixtures]]
            [test.support :as support]))

(use-fixtures :each support/with-temp-dir)

(defn- copy-site! []
  (doseq [directory ["bootstrap/site" "bootstrap/lib" "docs/assets" "tutorials"]]
    (fs/create-dirs (support/path directory)))
  (doseq [relative ["bootstrap/site/build_tutorial_pages.clj" "bootstrap/site/validate_site.clj"
                    "bootstrap/site/tutorial_page.html" "bootstrap/lib/common.clj" "bootstrap/lib/site.clj"
                    "docs/assets/site.css" "docs/assets/dotfiles.css" "docs/assets/site.js" "docs/sitemap.xml"]]
    (fs/copy (fs/path support/repo-root relative) (support/path relative)))
  (doseq [[directory pattern] [["docs" "*.html"] ["tutorials" "*.md"]]
          source (fs/glob (fs/path support/repo-root directory) pattern)]
    (fs/copy source (support/path directory (fs/file-name source)))))

(defn- run-site [script & args]
  (support/capture (into [support/bb (support/path "bootstrap/site" (str script ".clj"))] args)))

(defn- pages []
  (into {} (map (fn [path] [(fs/file-name path) (slurp (str path))]))
        (fs/glob (support/path "docs") "*.html")))

(deftest generation-and-checks-preserve-published-pages
  (copy-site!)
  (let [before (pages)
        source-count (count (fs/glob (support/path "tutorials") "*.md"))
        page-count (count (dissoc before "vim-performance.html"))
        generated (run-site "build_tutorial_pages")
        checked (run-site "build_tutorial_pages" "--check")
        validated (run-site "validate_site")]
    (is (zero? (:exit generated)) (:err generated))
    (is (= before (pages)))
    (is (zero? (:exit checked)) (:err checked))
    (is (str/includes? (:out checked) (str "match " source-count " Markdown sources")))
    (is (zero? (:exit validated)) (:err validated))
    (is (str/includes? (:out validated) (str "passed for " page-count " pages")))))

(deftest stale-pages-are-reported-without-writing-and-can-be-regenerated
  (copy-site!)
  (let [path (support/path "docs/fugitive.html")
        original (slurp path)]
    (spit path "stale page\n")
    (let [result (run-site "build_tutorial_pages" "--check")]
      (is (not (zero? (:exit result))))
      (is (str/includes? (:err result) "docs/fugitive.html"))
      (is (= "stale page\n" (slurp path))))
    (is (zero? (:exit (run-site "build_tutorial_pages"))))
    (is (= original (slurp path)))))

(deftest validator-rejects-canonical-byline-and-schema-mismatches
  (copy-site!)
  (let [path (support/path "docs/fugitive.html")
        original (slurp path)]
    (doseq [[label transform message]
            [["canonical" #(str/replace % "https://dot.marianposaceanu.com/fugitive.html"
                                         "https://dot.marianposaceanu.com/wrong.html") "expected canonical"]
             ["byline" #(str/replace % site/byline (str site/byline site/byline)) "missing or duplicate linked byline"]
             ["schema" #(str/replace % "\"@type\":\"TechArticle\"" "\"@type\":\"Article\"")
              "article schema disagrees"]]]
      (testing label
        (spit path (transform original))
        (let [result (run-site "validate_site")]
          (is (not (zero? (:exit result))))
          (is (str/includes? (:err result) message)))))))

(deftest validator-rejects-homepage-identity-and-sitemap-mismatches
  (copy-site!)
  (let [homepage (support/path "docs/index.html")
        original (slurp homepage)]
    (spit homepage (str/replace original #"\"name\"\s*:\s*\"dot-files\"" "\"name\":\"wrong\""))
    (let [result (run-site "validate_site")]
      (is (not (zero? (:exit result))))
      (is (str/includes? (:err result) "Homepage WebSite identity")))
    (spit homepage original)
    (let [sitemap (support/path "docs/sitemap.xml")]
      (spit sitemap (str/replace (slurp sitemap) "/fugitive.html" "/wrong.html"))
      (let [result (run-site "validate_site")]
        (is (not (zero? (:exit result))))
        (is (str/includes? (:err result) "Sitemap does not match"))))))

(deftest inline-formatting-and-escaping
  (is (= "<a href=\"/x?a=1&amp;b=2\"><code>a&lt;b</code></a> and <strong>bold</strong>"
         (site/inline "[`a<b`](/x?a=1&b=2) and **bold**")))
  (is (= "<code>**literal**</code> &amp; &#39;quote&#39;" (site/inline "`**literal**` & 'quote'")))
  (is (= "&<>'\"é😀" (site/unescape-html "&amp;&lt;&gt;&#39;&quot;&#xE9;&#128512;"))))

(deftest inline-text-cannot-collide-with-renderer-internals
  (is (= "INLINETOKEN0TOKEN and <code>x</code>" (site/inline "INLINETOKEN0TOKEN and `x`")))
  (is (= "<code>a</code> and <code>INLINETOKEN0TOKEN</code>"
         (site/inline "`a` and `INLINETOKEN0TOKEN`")))
  (is (= "<strong>before <code>**literal**</code> after</strong>"
         (site/inline "**before `**literal**` after**")))
  (is (= "<strong><a href=\"/x\">**literal**</a> after</strong>"
         (site/inline "**[**literal**](/x) after**"))))

(deftest charts-reject-invalid-rows-and-widths
  (doseq [lines [["```chart" "Title" "label|value|1001|meta" "```"]
                ["```chart" "Title" "label|value|oops|meta" "```"]
                ["```chart" "" "```"]]]
    (is (thrown? clojure.lang.ExceptionInfo (site/render-markdown lines)))))

(deftest front-matter-rejects-unclosed-or-empty-values
  (let [path (support/path "tutorial.md")]
    (doseq [content ["---\ncategory: Vim\n# Title\n" "---\ncategory:\n---\n# Title\n"]]
      (spit path content)
      (is (thrown? clojure.lang.ExceptionInfo (site/parse-tutorial (fs/file-name path) (slurp path)))))))

(support/run-tests! 'site-test)
