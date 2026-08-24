(require '[babashka.fs :as fs]
         '[babashka.process :as process]
         '[clojure.java.io :as io])

(def babashka-version "1.13.219")
(def babashka-sha256
  "57a45df1cee534081375f35d39a3cb5f334956e6d429e364adbf46e296d52cfb")
(def archive-name
  (str "babashka-" babashka-version "-macos-aarch64.tar.gz"))
(def download-url
  (str "https://github.com/babashka/babashka/releases/download/v"
       babashka-version "/" archive-name))

(def repo-root
  (-> *file* fs/parent fs/parent fs/parent fs/canonicalize str))
(def default-output
  (str (fs/path repo-root "bootstrap/bin/dotfiles-bootstrap-macos-aarch64")))

(load-file (str (fs/path repo-root "bootstrap/lib/common.clj")))

(defn usage []
  (println "Usage: bb bootstrap/binary/build.clj [--output <path>]"))

(defn parse-output [args]
  (case (count args)
    0 default-output
    2 (if (= "--output" (first args))
        (str (fs/absolutize (second args)))
        (do (usage) (System/exit 2)))
    (do (usage) (System/exit 2))))

(defn run! [& command]
  (apply process/shell command))

(defn sha256 [path]
  (let [digest (java.security.MessageDigest/getInstance "SHA-256")
        buffer (byte-array 65536)]
    (with-open [input (io/input-stream path)]
      (loop []
        (let [length (.read input buffer)]
          (when (pos? length)
            (.update digest buffer 0 length)
            (recur)))))
    (apply str (map #(format "%02x" (bit-and % 0xff)) (.digest digest)))))

(defn append-files! [output paths]
  (with-open [destination (io/output-stream output)]
    (doseq [path paths]
      (with-open [input (io/input-stream path)]
        (io/copy input destination)))))

(try
  (let [output (parse-output *command-line-args*)
        build-dir (fs/create-temp-dir {:prefix "dotfiles-bootstrap-build-"})
        archive (str (fs/path build-dir archive-name))
        runtime-dir (str (fs/path build-dir "runtime"))
        runtime (str (fs/path runtime-dir "bb"))
        source-dir (str (fs/path build-dir "sources"))
        uberjar (str (fs/path build-dir "dotfiles-bootstrap.jar"))
        current-bb (or (some-> (fs/which "bb") str)
                       (throw (ex-info "bb is required to build the binary" {})))]
    (try
      (bootstrap.lib.common/start-panel
       "STANDALONE ARM64 INSTALLER"
       (str "Embedding Babashka " babashka-version " for macOS aarch64"))

      (bootstrap.lib.common/section 1 5 "EMBEDDED CLOJURE SOURCES")
      (doseq [relative-path ["bootstrap/app/install_macos.clj"
                             "bootstrap/lib/common.clj"
                             "bootstrap/lib/progress.clj"]]
        (let [destination (fs/path source-dir relative-path)]
          (fs/create-dirs (fs/parent destination))
          (fs/copy (fs/path repo-root relative-path) destination)))
      (run! current-bb "--classpath" source-dir "uberjar" uberjar
            "-m" "bootstrap.app.install-macos")

      (bootstrap.lib.common/section 2 5 "PINNED BABASHKA RUNTIME")
      (bootstrap.lib.common/info
       (str "Downloading Babashka " babashka-version " for macOS aarch64..."))
      (run! "curl" "-fsSL" download-url "-o" archive)
      (let [actual-sha256 (sha256 archive)]
        (when-not (= babashka-sha256 actual-sha256)
          (throw (ex-info
                  (str "Babashka checksum mismatch: expected " babashka-sha256
                       ", got " actual-sha256)
                  {}))))

      (bootstrap.lib.common/section 3 5 "ARM64 RUNTIME")
      (bootstrap.lib.common/info "Extracting the pinned arm64 runtime...")
      (fs/create-dirs runtime-dir)
      (run! "tar" "-xzf" archive "-C" runtime-dir)

      (bootstrap.lib.common/section 4 5 "SELF-CONTAINED EXECUTABLE")
      (bootstrap.lib.common/info "Combining the runtime and embedded sources...")
      (fs/create-dirs (fs/parent output))
      (append-files! output [runtime uberjar])
      (run! "chmod" "+x" output)
      (spit (str output ".sha256")
            (str (sha256 output) "  " (fs/file-name output) "\n"))

      (bootstrap.lib.common/section 5 5 "BINARY VERIFICATION")
      (bootstrap.lib.common/info
       "Verifying the Mach-O binary and embedded entry point...")
      (let [{:keys [exit out]}
            (process/shell {:continue true :out :string :err :string}
                           "file" output)]
        (when (or (not (zero? exit))
                  (not (re-find #"Mach-O 64-bit executable arm64" out)))
          (throw (ex-info (str "Unexpected binary format: " out) {}))))
      (run! output "--help")

      (println)
      (bootstrap.lib.common/success-panel
       "BUILD COMPLETE"
       (str "Binary  " output)
       (format "Size    %.1f MiB" (/ (double (fs/size output)) 1048576.0))
       (str "SHA-256 " (sha256 output)))
      (finally
        (fs/delete-tree build-dir))))
  (catch Exception error
    (bootstrap.lib.common/abort! error)))
