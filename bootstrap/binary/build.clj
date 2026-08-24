(require '[babashka.classpath :as classpath]
         '[babashka.fs :as fs]
         '[clojure.java.io :as io])

(def ^:private babashka-version "1.13.219")
(def ^:private babashka-sha256
  "57a45df1cee534081375f35d39a3cb5f334956e6d429e364adbf46e296d52cfb")
(def ^:private archive-name
  (str "babashka-" babashka-version "-macos-aarch64.tar.gz"))
(def ^:private download-url
  (str "https://github.com/babashka/babashka/releases/download/v"
       babashka-version "/" archive-name))

(def ^:private repo-root
  (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))
(def ^:private default-output
  (str (fs/path repo-root "bootstrap/bin/dotfiles-bootstrap-macos-aarch64")))
(def ^:private usage
  "Usage: bb bootstrap/binary/build.clj [--output <path>]")
(def ^:private embedded-sources
  ["bootstrap/app/install_macos.clj"
   "bootstrap/lib/common.clj"
   "bootstrap/lib/progress.clj"])

(classpath/add-classpath repo-root)
(require '[bootstrap.lib.common :as common])

(defn- parse-output [args]
  (cond
    (empty? args) default-output
    (and (= 2 (count args)) (= "--output" (first args)))
    (str (fs/absolutize (second args)))
    :else (common/usage-error! usage)))

(defn- sha-256 [path]
  (let [digest (java.security.MessageDigest/getInstance "SHA-256")
        buffer (byte-array 65536)]
    (with-open [input (io/input-stream (str path))]
      (loop []
        (let [length (.read input buffer)]
          (when (pos? length)
            (.update digest buffer 0 length)
            (recur)))))
    (apply str (map #(format "%02x" (bit-and % 0xff)) (.digest digest)))))

(defn- append-files! [output paths]
  (with-open [destination (io/output-stream (str output))]
    (doseq [path paths]
      (with-open [input (io/input-stream (str path))]
        (io/copy input destination)))))

(defn- build-paths [output]
  (let [directory (fs/create-temp-dir {:prefix "dotfiles-bootstrap-build-"})]
    {:directory directory
     :archive (fs/path directory archive-name)
     :runtime-directory (fs/path directory "runtime")
     :runtime (fs/path directory "runtime/bb")
     :source-directory (fs/path directory "sources")
     :uberjar (fs/path directory "dotfiles-bootstrap.jar")
     :output output}))

(defn- embed-sources! [{:keys [source-directory uberjar]} current-bb]
  (common/section 1 5 "EMBEDDED CLOJURE SOURCES")
  (doseq [relative-path embedded-sources]
    (let [destination (fs/path source-directory relative-path)]
      (fs/create-dirs (fs/parent destination))
      (fs/copy (fs/path repo-root relative-path) destination)))
  (common/run! [current-bb "--classpath" (str source-directory)
                "uberjar" (str uberjar) "-m" "bootstrap.app.install-macos"]))

(defn- download-runtime! [{:keys [archive]}]
  (common/section 2 5 "PINNED BABASHKA RUNTIME")
  (common/info
   (str "Downloading Babashka " babashka-version " for macOS aarch64..."))
  (common/run! ["curl" "-fsSL" download-url "-o" (str archive)])
  (let [actual-checksum (sha-256 archive)]
    (when-not (= babashka-sha256 actual-checksum)
      (throw (ex-info
              (str "Babashka checksum mismatch: expected " babashka-sha256
                   ", got " actual-checksum)
              {})))))

(defn- extract-runtime! [{:keys [archive runtime-directory]}]
  (common/section 3 5 "ARM64 RUNTIME")
  (common/info "Extracting the pinned arm64 runtime...")
  (fs/create-dirs runtime-directory)
  (common/run! ["tar" "-xzf" (str archive) "-C" (str runtime-directory)]))

(defn- create-executable! [{:keys [output runtime uberjar]}]
  (common/section 4 5 "SELF-CONTAINED EXECUTABLE")
  (common/info "Combining the runtime and embedded sources...")
  (fs/create-dirs (fs/parent output))
  (append-files! output [runtime uberjar])
  (common/run! ["chmod" "+x" output])
  (spit (str output ".sha256")
        (str (sha-256 output) "  " (fs/file-name output) "\n")))

(defn- verify-executable! [{:keys [output]}]
  (common/section 5 5 "BINARY VERIFICATION")
  (common/info "Verifying the Mach-O binary and embedded entry point...")
  (let [{:keys [exit out]} (common/result ["file" output])]
    (when (or (not (zero? exit))
              (not (re-find #"Mach-O 64-bit executable arm64" out)))
      (throw (ex-info (str "Unexpected binary format: " out) {}))))
  (common/run! [output "--help"]))

(defn- build! [output]
  (let [current-bb (or (some-> (fs/which "bb") str)
                       (throw (ex-info "bb is required to build the binary" {})))
        paths (build-paths output)]
    (try
      (common/start-panel
       "STANDALONE ARM64 INSTALLER"
       (str "Embedding Babashka " babashka-version " for macOS aarch64"))
      (embed-sources! paths current-bb)
      (download-runtime! paths)
      (extract-runtime! paths)
      (create-executable! paths)
      (verify-executable! paths)

      (println)
      (common/success-panel
       "BUILD COMPLETE"
       (str "Binary  " output)
       (format "Size    %.1f MiB" (/ (double (fs/size output)) 1048576.0))
       (str "SHA-256 " (sha-256 output)))
      (finally
        (fs/delete-tree (:directory paths))))))

(defn -main [& args]
  (build! (parse-output args)))

(common/run-script! -main *command-line-args*)
