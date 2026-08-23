(ns bootstrap.lib.common
  (:require [babashka.fs :as fs]
            [babashka.process :as process]
            [clojure.string :as str])
  (:import [java.nio.file Files LinkOption Path]
           [java.time LocalDateTime]
           [java.time.format DateTimeFormatter]))

(def ^:private no-follow-links
  (into-array LinkOption [LinkOption/NOFOLLOW_LINKS]))

(def color?
  (and (some? (System/console))
       (str/blank? (System/getenv "NO_COLOR"))
       (not= "dumb" (System/getenv "TERM"))))

(defn- styled [code text]
  (if color?
    (str "\u001b[" code "m" text "\u001b[0m")
    text))

(defn success [message]
  (println (styled "1;32" (str "✓ " message))))

(defn info [message]
  (println (styled "1;34" (str "• " message))))

(defn warning [message]
  (println (styled "1;33" (str "! " message))))

(defn failure [message]
  (binding [*out* *err*]
    (println (styled "1;31" (str "✗ Error: " message)))))

(defn abort! [error]
  (failure (or (some-> error .getMessage str/trim not-empty)
               (str error)))
  (System/exit 1))

(defn section [number total title]
  (println)
  (println (styled "1;36" (format "[%02d/%02d] %s" number total title))))

(defn command-path [command]
  (some-> (fs/which command) str))

(defn run!
  ([command]
   (apply process/shell command))
  ([opts command]
   (apply process/shell opts command)))

(defn result [command]
  (apply process/shell {:continue true :out :string :err :string} command))

(defn capture [command]
  (let [{:keys [exit out err]} (result command)]
    (when-not (zero? exit)
      (throw (ex-info (or (some-> err str/trim not-empty)
                          (str "Command failed: " (str/join " " command)))
                      {:exit exit :command command})))
    (str/trim out)))

(defn path-present? [path]
  (Files/exists (fs/path path) no-follow-links))

(defn canonical [path]
  (str (fs/canonicalize path)))

(def link-specs
  [{:source ".vimrc" :target ".vimrc" :label "~/.vimrc"}
   {:source ".vim" :target ".vim" :label "~/.vim"}
   {:source ".gitconfig" :target ".gitconfig" :label "~/.gitconfig"}
   {:source ".gitignore_global" :target ".gitignore_global" :label "~/.gitignore_global"}
   {:source ".tmux.conf" :target ".tmux.conf" :label "~/.tmux.conf"}
   {:source ".zprofile" :target ".zprofile" :label "~/.zprofile"}
   {:source ".zshrc" :target ".zshrc" :label "~/.zshrc"}
   {:source ".zlogin" :target ".zlogin" :label "~/.zlogin"}
   {:source ".bashrc" :target ".bashrc" :label "~/.bashrc"}
   {:source "codex/config.toml" :target ".codex/config.toml" :label "Codex config"}
   {:source "amp/settings.json" :target ".config/amp/settings.json" :label "Amp settings"}
   {:source "bat" :target ".config/bat" :label "bat config"}
   {:source "ghostty/config"
    :target "Library/Application Support/com.mitchellh.ghostty/config"
    :label "Ghostty config"}])

(defn resolved-link-specs [repo-root]
  (let [home (or (System/getenv "HOME") (System/getProperty "user.home"))]
    (mapv #(-> %
               (update :source (fn [path] (str (fs/path repo-root path))))
               (update :target (fn [path] (str (fs/path home path)))))
          link-specs)))

(defn link-target [path]
  (let [link (fs/path path)
        target (Files/readSymbolicLink link)]
    (if (.isAbsolute ^Path target)
      target
      (.resolve (.getParent ^Path link) target))))

(defn correct-link? [source target]
  (and (fs/sym-link? target)
       (try
         (= (canonical source) (canonical (link-target target)))
         (catch Exception _ false))))

(defn backup-path [target stamp]
  (loop [candidate (str target ".backup." stamp)
         suffix 1]
    (if (path-present? candidate)
      (recur (str target ".backup." stamp "." suffix) (inc suffix))
      candidate)))

(defn link-configs! [repo-root]
  (let [stamp (.format (LocalDateTime/now)
                       (DateTimeFormatter/ofPattern "yyyyMMddHHmmss"))]
    (reduce
     (fn [counts {:keys [source target]}]
       (when-not (path-present? source)
         (throw (ex-info (str "Source does not exist: " source) {:source source})))
       (if (correct-link? source target)
         (update counts :unchanged inc)
         (do
           (fs/create-dirs (fs/parent target))
           (let [backed-up? (path-present? target)]
             (when backed-up?
               (fs/move target (backup-path target stamp)))
             (fs/create-sym-link target source)
             (cond-> (update counts :updated inc)
               backed-up? (update :backups inc))))))
     {:unchanged 0 :updated 0 :backups 0}
     (resolved-link-specs repo-root))))

(defn summary [{:keys [unchanged updated backups]}]
  (format "%d unchanged, %d updated, %d %s."
          unchanged updated backups (if (= backups 1) "backup" "backups")))
