(ns bootstrap.lib.site
  (:require [babashka.fs :as fs]
            [cheshire.core :as json]
            [clojure.string :as str])
  (:import [java.security MessageDigest]
           [java.math BigInteger]))

(def base-url "https://dot.marianposaceanu.com")
(def person
  {"@type" "Person"
   "@id" "https://marianposaceanu.com/#person"
   "name" "Marian Posăceanu"
   "url" "https://marianposaceanu.com/home/about"})
(def website
  {"@context" "https://schema.org"
   "@type" "WebSite"
   "@id" (str base-url "/#website")
   "url" (str base-url "/")
   "name" "dot-files"
   "alternateName" "Marian’s macOS dotfiles"
   "publisher" {"@id" (get person "@id")}})
(def byline "<li>By <a href=\"https://marianposaceanu.com/home/about\">Marian Posăceanu</a></li>")

(defn ensure! [condition message]
  (when-not condition (throw (ex-info message {}))))

(defn escape-html [text]
  (str/escape (str text) {\& "&amp;" \< "&lt;" \> "&gt;" \" "&quot;" \' "&#39;"}))

(defn unescape-html [text]
  (str/replace (or text "") #"&(?:amp|lt|gt|quot|apos|#\d+|#x[0-9a-fA-F]+);"
               (fn [entity]
                 (or ({"&amp;" "&" "&lt;" "<" "&gt;" ">" "&quot;" "\"" "&apos;" "'"} entity)
                     (let [hex? (str/starts-with? entity "&#x")
                           digits (subs entity (if hex? 3 2) (dec (count entity)))
                           codepoint (Integer/parseInt digits (if hex? 16 10))]
                       (String. (Character/toChars codepoint)))))))

(defn slug [text]
  (-> text str/lower-case (str/replace #"[^a-z0-9]+" "-") (str/replace #"^-|-$" "")))

(def ^:private inline-pattern #"(?s)`([^`\n]+)`|\[([^\]]+)\]\(([^)]+)\)|\*\*")
(def ^:private code-and-link-pattern #"(?s)`([^`\n]+)`|\[([^\]]+)\]\(([^)]+)\)")
(def ^:private code-pattern #"`([^`\n]+)`")

(defn- strong-end [text start]
  (let [matcher (re-matcher inline-pattern text)]
    (.region matcher start (count text))
    (loop []
      (when (.find matcher)
        (if (and (= "**" (.group matcher)) (> (.start matcher) start))
          (when-not (str/includes? (subs text start (.start matcher)) "\n")
            (.start matcher))
          (recur))))))

(defn- inline-fragments
  ([text] (inline-fragments text inline-pattern))
  ([text pattern]
   (let [matcher (re-matcher pattern text)]
     (loop [offset 0 fragments []]
       (if (.find matcher offset)
         (let [start (.start matcher)
               end (.end matcher)
               output (cond-> fragments (< offset start)
                        (conj {:type :text :value (subs text offset start)}))]
           (cond
             (.group matcher 1)
             (recur end (conj output {:type :code :value (.group matcher 1)}))

             (= "**" (.group matcher))
             (if-let [closing (strong-end text end)]
               (recur (+ closing 2)
                      (conj output {:type :strong
                                    :children (inline-fragments (subs text end closing) code-and-link-pattern)}))
               (recur end (conj output {:type :text :value "**"})))

             :else
             (recur end (conj output {:type :link :href (.group matcher 3)
                                      :children (inline-fragments (.group matcher 2) code-pattern)}))))
         (cond-> fragments (< offset (count text))
           (conj {:type :text :value (subs text offset)})))))))

(defn- render-inline [fragments]
  (apply str
         (map (fn [{:keys [type value href children]}]
                (case type
                  :text (escape-html value)
                  :code (str "<code>" (escape-html value) "</code>")
                  :link (str "<a href=\"" (escape-html href) "\">" (render-inline children) "</a>")
                  :strong (str "<strong>" (render-inline children) "</strong>")))
              fragments)))

(defn inline [text]
  (-> text inline-fragments render-inline))

(defn- table-cells [line]
  (->> (str/split (str/replace (str/trim line) #"^\||\|$" "") #"\|")
       (mapv str/trim)))

(defn- table-separator? [line]
  (when line
    (let [cells (table-cells line)]
      (and (seq cells) (every? #(re-matches #":?-{3,}:?" %) cells)))))

(defn- table? [lines]
  (and (str/starts-with? (str/trim (first lines)) "|") (table-separator? (second lines))))

(defn- structural? [lines]
  (let [line (str/trim (first lines))]
    (or (str/blank? line) (= line "---")
        (some #(str/starts-with? line %) ["#" "```" "> "])
        (re-find #"^(?:[-*] |\d+\. )" line) (table? lines))))

(defn- chart-row [line]
  (let [[label value width meta] (mapv str/trim (str/split line #"\|" 4))]
    (ensure! (and label value width (re-matches #"\d{2,4}" width) meta)
             (str "Invalid chart row: " line))
    (ensure! (<= 0 (parse-long width) 1000) (str "Chart width out of range: " width))
    {:label label :value value :width width :meta meta}))

(defn- render-chart-row [{:keys [label value width meta]}]
  ["          <div class=\"bar-row\">"
   (str "            <div class=\"bar-label\"><strong>" (inline label) "</strong><span>" (inline value) "</span></div>")
   (str "            <div class=\"bar-track\"><span class=\"bar-fill bar-width-" width "\"></span></div>")
   (str "            <div class=\"bar-meta\">" (inline meta) "</div>")
   "          </div>"])

(defn- chart [lines]
  (let [title (str/trim (or (first lines) ""))
        rows (into [] (comp (remove str/blank?) (map chart-row)) (rest lines))
        aria (str/join ", " (map (fn [{:keys [label value]}] (str label " " value)) rows))]
    (ensure! (and (not (str/blank? title)) (seq rows)) "Chart requires a title and rows")
    (conj (into [(str "        <figure class=\"chart\" role=\"img\" aria-label=\"" (escape-html (str title ": " aria)) "\">")
                 (str "          <figcaption class=\"chart-title\">" (inline title) "</figcaption>")]
                (mapcat render-chart-row) rows)
          "        </figure>")))

(defn- table-row [tag cells]
  (apply str (map #(str "<" tag ">" (inline %) "</" tag ">") cells)))

(defn- render-table [header rows]
  (into ["        <div class=\"table-scroll\">" "          <table>"
         (str "            <thead><tr>" (table-row "th" (table-cells header)) "</tr></thead>")
         "            <tbody>"]
        (concat (map #(str "              <tr>" (table-row "td" (table-cells %)) "</tr>") rows)
                ["            </tbody>" "          </table>" "        </div>"])))

(defn- render-list [tag pattern lines]
  (into [(str "        <" tag ">")]
        (concat (map #(str "          <li>" (inline (str/replace (str/trim %) pattern "")) "</li>") lines)
                [(str "        </" tag ">")])))

(defn- take-paragraph [lines]
  (loop [paragraph [(first lines)] remaining (next lines)]
    (if (and remaining (not (structural? remaining)))
      (recur (conj paragraph (first remaining)) (next remaining))
      [paragraph remaining])))

(defn render-markdown [lines]
  (loop [lines (seq lines) section? false output []]
    (if-not lines
      (str/join "\n" (cond-> output section? (conj "      </section>")))
      (let [line (str/trim (first lines))]
        (cond
          (or (str/blank? line) (= line "---"))
          (recur (next lines) section? output)

          (str/starts-with? line "## ")
          (let [heading (subs line 3)]
            (recur (next lines) true
                   (into (cond-> output section? (conj "      </section>"))
                         [(str "      <section id=\"" (slug heading) "\">")
                          (str "        <h2>" (inline heading) "</h2>")])))

          (str/starts-with? line "### ")
          (recur (next lines) section? (conj output (str "        <h3>" (inline (subs line 4)) "</h3>")))

          (str/starts-with? line "```")
          (let [language (str/trim (subs line 3))
                [code remaining] (split-with #(not (str/starts-with? (str/trim %) "```")) (rest lines))
                rendered (if (= language "chart")
                           (chart code)
                           [(str "        <pre><code"
                                 (when-not (str/blank? language) (str " class=\"language-" (escape-html language) "\""))
                                 ">" (escape-html (str/join "\n" code)) "</code></pre>")])]
            (recur (next remaining) section? (into output rendered)))

          (table? lines)
          (let [[rows remaining] (split-with #(str/starts-with? (str/trim %) "|") (drop 2 lines))]
            (recur (seq remaining) section? (into output (render-table (first lines) rows))))

          (re-find #"^(?:[-*] |\d+\. )" line)
          (let [ordered? (boolean (re-find #"^\d+\. " line))
                pattern (if ordered? #"^\d+\. " #"^[-*] ")
                [items remaining] (split-with #(re-find pattern (str/trim %)) lines)]
            (recur (seq remaining) section? (into output (render-list (if ordered? "ol" "ul") pattern items))))

          (str/starts-with? line "> ")
          (let [[quotes remaining] (split-with #(str/starts-with? (str/trim %) "> ") lines)]
            (recur (seq remaining) section?
                   (conj output (str "        <blockquote><p>"
                                     (inline (str/join " " (map #(subs (str/trim %) 2) quotes))) "</p></blockquote>"))))

          :else
          (let [[paragraph remaining] (take-paragraph lines)]
            (recur remaining section?
                   (conj output (str "        <p>" (inline (str/join " " (map str/trim paragraph))) "</p>")))))))))

(defn- front-matter [lines path]
  (if (= "---" (first lines))
    (let [[metadata remaining] (split-with #(not= "---" %) (rest lines))]
      (ensure! (seq remaining) (str "Unclosed front matter in " path))
      {:metadata (into {} (map (fn [line]
                                (let [[key value] (map str/trim (str/split line #":" 2))]
                                  (ensure! (and (not (str/blank? key)) (not (str/blank? value)))
                                           (str "Invalid front matter in " path ": " line))
                                  [key value]))) metadata)
       :lines (rest remaining)})
    {:metadata {} :lines lines}))

(defn canonical-url [path]
  (str base-url "/" (when-not (= "index.html" (fs/file-name path)) (fs/file-name path))))

(defn article-schema [{:keys [type canonical title description published]}]
  {"@context" "https://schema.org" "@type" type
   "mainEntityOfPage" {"@type" "WebPage" "@id" canonical}
   "headline" title "description" description "author" person "datePublished" published})

(defn asset-hash [path]
  (let [digest (.digest (MessageDigest/getInstance "SHA-256") (fs/read-all-bytes path))]
    (subs (format "%064x" (BigInteger. 1 digest)) 0 12)))

(defn parse-tutorial [source-name markdown]
  (let [{:keys [metadata lines]} (front-matter (str/split-lines markdown) source-name)
        title (-> (or (first lines) "") (str/replace #"^# " "") str/trim)
        _ (ensure! (not (str/blank? title)) (str "Missing H1 in " source-name))
        [intro remaining] (split-with #(not (contains? #{"" "---"} (str/trim %)))
                                     (drop-while str/blank? (rest lines)))
        body (rest remaining)]
    {:title title
     :description (str/join " " (map str/trim intro))
     :body body
     :headings (keep #(when (str/starts-with? (str/trim %) "## ") (subs (str/trim %) 3)) body)
     :canonical (str base-url "/" (slug (fs/strip-ext source-name)) ".html")
     :published (get metadata "published" "2026-07-20")
     :visible-date (get metadata "visible-date" "20th July 2026")
     :category (get metadata "category" "Vim tutorial")
     :eyebrow (get metadata "eyebrow" "Vim field guide · dot-files")}))

(defn page [template asset-hashes {:keys [body headings canonical] :as tutorial}]
  (let [escaped (reduce-kv (fn [values key value] (assoc values (name key) (escape-html value)))
                           {} (select-keys tutorial [:title :description :published :visible-date :category :eyebrow]))
        values (merge asset-hashes escaped
                      {"canonical" canonical
                       "schema" (json/generate-string (article-schema (assoc tutorial :type "TechArticle")))
                       "toc" (str/join "\n" (map #(str "        <li><a href=\"#" (slug %) "\">" (inline %) "</a></li>") headings))
                       "body" (render-markdown body)})]
    (str/replace template #"\{\{([a-z-]+)\}\}" (fn [[_ key]] (get values key)))))
