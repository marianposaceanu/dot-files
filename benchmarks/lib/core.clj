(ns benchmarks.lib.core
  (:require [babashka.fs :as fs]
            [babashka.process :as process]
            [bootstrap.lib.common :as common]
            [cheshire.core :as json]
            [clojure.string :as str])
  (:import [java.time Instant ZoneOffset]
           [java.time.format DateTimeFormatter]
           [java.security MessageDigest]
           [java.util.concurrent TimeUnit]))

(def repo-root (str (-> *file* fs/canonicalize fs/parent fs/parent fs/parent)))
(def bench-root (str (fs/path repo-root "benchmarks")))

(defn env [name fallback] (or (System/getenv name) fallback))
(defn path [& parts] (str (apply fs/path parts)))
(defn now [] (str (Instant/now)))
(defn timestamp [] (.format (.withZone (DateTimeFormatter/ofPattern "yyyyMMdd'T'HHmmssSSS'Z'") ZoneOffset/UTC) (Instant/now)))
(defn fail! [message data] (throw (ex-info message data)))

(defn integer-option [name value minimum]
  (let [n (parse-long (str value))]
    (when-not (and n (<= minimum n))
      (fail! (str name " must be an integer >= " minimum) {:option name :value value}))
    n))

(defn number-option [name value]
  (let [n (try (Double/parseDouble (str value)) (catch Exception _ nil))]
    (when-not (and n (Double/isFinite n) (pos? n))
      (fail! (str name " must be a positive finite number") {:option name :value value}))
    n))

(defn executable [command]
  (let [binary (or (some-> (fs/which command) str) command)]
    (when-not (and binary (fs/regular-file? binary) (fs/executable? binary))
      (fail! (str "Executable not found: " command) {:command command}))
    (str (fs/absolutize binary))))

(defn capture!
  ([command] (capture! {} command))
  ([options command]
   (let [result @(apply process/process (merge {:out :string :err :string} options) command)]
     (when-not (zero? (:exit result))
       (fail! (str "Command failed: " (str/join " " command) "\n" (:err result))
              (assoc result :command command)))
     result)))

(defn output! [command] (:out (capture! command)))
(defn version [binary] (first (str/split-lines (output! [binary "--version"]))))
(defn elapsed-ms [] (/ (System/nanoTime) 1000000.0))

(defn median [values]
  (when (empty? values) (fail! "Cannot summarize empty samples" {}))
  (let [values (vec (sort values)) n (count values) middle (quot n 2)]
    (if (odd? n) (nth values middle) (/ (+ (nth values (dec middle)) (nth values middle)) 2.0))))

(defn mean [values]
  (when (empty? values) (fail! "Cannot average empty samples" {}))
  (/ (reduce + values) (double (count values))))

(defn summary [values]
  {:median (median values) :minimum (apply min values) :maximum (apply max values)})

(defn timed! [options command]
  (let [start (elapsed-ms)]
    (capture! (merge {:out :write :out-file "/dev/null"} options) command)
    (- (elapsed-ms) start)))

(defn sample-pair!
  "Alternate candidates by sample index, keeping samples independent even for identical paths."
  [measure! binaries warmups repetitions]
  (doseq [_ (range warmups) binary binaries] (measure! binary))
  (reduce (fn [samples index]
            (reduce (fn [result position]
                      (update result position conj (measure! (nth binaries position))))
                    samples (cond-> (vec (range (count binaries))) (odd? index) reverse)))
          (vec (repeat (count binaries) [])) (range repetitions)))

(defn with-temp-dir [f]
  (let [directory (fs/create-temp-dir {:prefix "dot-files-benchmark-"})]
    (try (f (str directory)) (finally (fs/delete-tree directory)))))

(defn write! [target content]
  (fs/create-dirs (fs/parent target))
  (spit target content)
  target)

(defn atomic-write! [target content]
  (fs/create-dirs (fs/parent target))
  (let [pending (fs/create-temp-file {:dir (fs/parent target) :prefix ".benchmark-"})]
    (try
      (spit (str pending) content)
      (fs/move pending target {:replace-existing true :atomic-move true})
      (finally (fs/delete-if-exists pending))))
  target)

(defn sha256 [file]
  (let [digest (MessageDigest/getInstance "SHA-256")]
    (with-open [input (java.io.FileInputStream. (str file))]
      (let [buffer (byte-array 8192)]
        (loop []
          (let [n (.read input buffer)]
            (when (pos? n) (.update digest buffer 0 n) (recur))))))
    (apply str (map #(format "%02x" (bit-and 255 %)) (.digest digest)))))

(defn json-string [value] (str (json/generate-string value {:pretty true}) "\n"))
(defn shell-quote [value] (str "'" (str/replace (str value) "'" "'\"'\"'") "'"))

(defn stop-process! [child]
  (let [root (.toHandle (:proc child))
        descendants (with-open [stream (.descendants root)]
                      (vec (.toArray stream)))]
    ;; ProcessHandle avoids blocking on output pipes inherited by descendants.
    (doseq [handle (conj descendants root)]
      (when (.isAlive handle) (.destroy handle)))
    (.waitFor (:proc child) 1000 TimeUnit/MILLISECONDS)
    ;; Keep the handles: Chrome children can outlive their terminating parent.
    (doseq [handle (conj descendants root)]
      (when (.isAlive handle) (.destroyForcibly handle)))
    (deref child 2000 nil)))

(defn run-cli! [main]
  (when (and *file* (= (str (fs/canonicalize *file*)) (some-> (System/getProperty "babashka.file") fs/canonicalize str)))
    (common/run-script! main *command-line-args*)))
