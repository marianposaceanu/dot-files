(ns bootstrap.lib.ruby-warnings
  (:refer-clojure :exclude [run!])
  (:require [babashka.fs :as fs]
            [bootstrap.lib.common :as common]
            [clojure.string :as str]))

(def ^:private extension-warning
  #"Ignoring (.+) because its extensions are not built\. Try: .+")

(defn- runtime-key [{:keys [ruby gem-home gem-path probe-failed?]}]
  (cond-> {:ruby (common/canonical ruby)}
    gem-home (assoc :gem-home gem-home)
    gem-path (assoc :gem-path gem-path)
    probe-failed? (assoc :probe-failed? true)))

(defn- remember! [warnings runtime gems]
  (when (seq gems)
    (swap! warnings update (runtime-key runtime)
           (fn [entry]
             (update (or entry {:runtime runtime :gems (sorted-set)}) :gems into gems)))))

(defn- command [{:keys [ruby gem-home gem-path]} & args]
  (into (cond-> ["env" "-u" "GEM_HOME" "-u" "GEM_PATH"]
          gem-home (conj (str "GEM_HOME=" gem-home))
          gem-path (conj (str "GEM_PATH=" gem-path)))
        (cons ruby args)))

(defn run!
  ([warnings runtime args]
   (run! warnings runtime {} args))
  ([warnings runtime opts args]
   (let [cmd (apply command runtime args)
         {:keys [exit out err] :as result}
         (common/run! (merge opts {:continue true :err :string}) cmd)]
     (doseq [line (str/split-lines err)]
       (if-let [[_ gem] (re-matches extension-warning line)]
         (remember! warnings runtime [gem])
         (binding [*out* *err*] (println line))))
     (when-not (zero? exit)
       (when (and (= :string (:out opts)) (not (str/blank? out)))
         (binding [*out* *err*]
           (print out)
           (flush)))
       (throw (ex-info (str "Ruby check failed (exit " exit "): " (str/join " " args))
                       {:exit exit :command cmd})))
     result)))

(defn- homebrew-runtimes []
  (for [prefix ["/opt/homebrew" "/usr/local"]
        :let [ruby (str (fs/path prefix "opt/ruby/bin/ruby"))]
        :when (fs/executable? ruby)]
    {:label "Homebrew Ruby" :ruby ruby}))

(defn- rvm-runtimes [active]
  (let [home (or (System/getenv "HOME") (System/getProperty "user.home"))
        rvm-root (or (System/getenv "rvm_path") (str (fs/path home ".rvm")))]
    (for [dir (sort (fs/glob (fs/path rvm-root "rubies") "ruby-*"))
          :let [ruby (str (fs/path dir "bin/ruby"))]
          :when (fs/executable? ruby)
          :let [gem-home (str (fs/path rvm-root "gems" (fs/file-name dir)))
                gem-path (str gem-home ":" gem-home "@global")
                active? (and active (= (common/canonical ruby)
                                       (common/canonical (:ruby active))))]]
      {:label (str "RVM " (fs/file-name dir))
       :ruby ruby
       :gem-home (or (when active? (System/getenv "GEM_HOME")) gem-home)
       :gem-path (or (when active? (System/getenv "GEM_PATH")) gem-path)})))

(defn runtimes []
  (let [active (when-let [ruby (common/command-path "ruby")]
                 {:label "Ruby used by config checks" :ruby ruby})]
    ;; The same executable with a different gem environment needs its own scan.
    (->> (concat [active] (homebrew-runtimes) (rvm-runtimes active))
         (remove nil?)
         (into {} (map (juxt runtime-key identity)))
         vals)))

(def ^:private probe
  (str "require 'rubygems'; "
       "puts Gem::Specification.select(&:missing_extensions?).map(&:full_name)"))

(defn inspect! [warnings]
  (doseq [runtime (runtimes)]
    (let [{:keys [exit out err]} (common/result (command runtime "-e" probe))]
      (if (zero? exit)
        (remember! warnings runtime (remove str/blank? (str/split-lines out)))
        (remember! warnings (assoc runtime :probe-failed? true)
                   [(str "Could not inspect gems: " (str/trim err))])))))

(defn- shell-quote [value]
  (if (re-matches #"[A-Za-z0-9_./:@=+-]+" value)
    value
    (str "'" (str/replace value "'" "'\"'\"'") "'")))

(defn repair-command [runtime]
  (str/join " " (map shell-quote
                         (command runtime
                                  (str (fs/path (fs/parent (:ruby runtime)) "gem"))
                                  "pristine" "--all" "--only-missing-extensions"))))

(defn report! [warnings]
  (when (seq @warnings)
    (println)
    (common/warning-panel
     "RUBY ENVIRONMENT WARNINGS"
     "Configuration results are reported above. Review these environment issues separately.")
    (doseq [{:keys [runtime gems]} (sort-by (comp :label :runtime) (vals @warnings))]
      (println)
      (common/warning (:label runtime))
      (println (str "  Ruby: " (:ruby runtime)))
      (doseq [gem gems]
        (println (str "  • " gem)))
      (if (:probe-failed? runtime)
        (println "  Next step: check this Ruby installation and its gem environment.")
        (do
          (println "  Missing native extensions. Rebuild with:")
          (println (str "    " (repair-command runtime))))))
    (println)
    (println "  Then rerun: bb bootstrap/checks/check_configs.clj")))
