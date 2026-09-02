(ns bootstrap.lib.common
  (:refer-clojure :exclude [run!])
  (:require [babashka.fs :as fs]
            [babashka.process :as process]
            [clojure.string :as str])
  (:import [java.time LocalDateTime]
           [java.time.format DateTimeFormatter]))

(def ^:private color-output?
  (and (some? (System/console))
       (str/blank? (System/getenv "NO_COLOR"))
       (not= "dumb" (System/getenv "TERM"))))

(defn- styled [code text]
  (if color-output?
    (str "\u001b[" code "m" text "\u001b[0m")
    text))

(def ^:private tone-codes
  {:info "1;36"
   :success "1;32"
   :failure "1;31"})

(defn- panel [tone title details]
  (let [lines (remove nil? details)]
    (println (styled (get tone-codes tone "1;36") (str "╭─ " title)))
    (doseq [line (butlast lines)]
      (println (str "│  " line)))
    (if-let [line (last lines)]
      (println (str "╰─ " line))
      (println "╰─"))))

(defn start-panel [title & details]
  (panel :info title details))

(defn success-panel [title & details]
  (panel :success title details))

(defn failure-panel [title & details]
  (panel :failure title details))

(defn success [message]
  (println (styled "1;32" (str "✓ " message))))

(defn info [message]
  (println (styled "1;34" (str "• " message))))

(defn warning [message]
  (println (styled "1;33" (str "! " message))))

(defn failure [message]
  (binding [*out* *err*]
    (failure-panel "COMMAND FAILED" message)))

(defn usage-error! [usage]
  (binding [*out* *err*]
    (println usage))
  (System/exit 2))

(defn abort! [error]
  (failure (or (some-> error .getMessage str/trim not-empty)
               (str error)))
  (System/exit 1))

(defn run-script! [main args]
  (try
    (apply main args)
    (catch Exception error
      (abort! error))))

(defn section [number total title]
  (println)
  (start-panel (format "[%02d/%02d] %s" number total title)))

(defn heading [title]
  (println)
  (start-panel title))

(defn command-path [command]
  (some-> (fs/which command) str))

(defn run!
  ([command]
   (apply process/shell command))
  ([opts command]
   (apply process/shell opts command)))

(defn result [command]
  (run! {:continue true :out :string :err :string} command))

(defn successful? [command]
  (zero? (:exit (result command))))

(defn capture [command]
  (let [{:keys [exit out err]} (result command)]
    (when-not (zero? exit)
      (throw (ex-info (or (some-> err str/trim not-empty)
                          (str "Command failed: " (str/join " " command)))
                      {:exit exit :command command})))
    (str/trim out)))

(defn brew-bundle-command [brew brewfile]
  (let [help-output (:out (result [brew "bundle" "--help"]))]
    (cond-> [brew "bundle" "--file" (str brewfile)]
      (str/includes? help-output "--no-lock") (conj "--no-lock"))))

(defn path-present? [path]
  (fs/exists? path {:nofollow-links true}))

(defn canonical [path]
  (str (fs/canonicalize path)))

(def ^:private link-specs
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
   {:source "claude/settings.json" :target ".claude/settings.json" :label "Claude Code settings"}
   {:source "claude/output-styles/amp.md"
    :target ".claude/output-styles/amp.md"
    :label "Claude Code Amp output style"}
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

(defn correct-link? [source target]
  (and (fs/sym-link? target)
       (try
         (= (canonical source) (canonical target))
         (catch Exception _ false))))

(defn- next-backup-path [target timestamp]
  (loop [candidate (str target ".backup." timestamp)
         suffix 1]
    (if (path-present? candidate)
      (recur (str target ".backup." timestamp "." suffix) (inc suffix))
      candidate)))

(defn- link-config! [timestamp counts {:keys [source target]}]
  (when-not (path-present? source)
    (throw (ex-info (str "Source does not exist: " source) {:source source})))

  (if (correct-link? source target)
    (update counts :unchanged inc)
    (let [backed-up? (path-present? target)]
      (fs/create-dirs (fs/parent target))
      (when backed-up?
        (fs/move target (next-backup-path target timestamp)))
      (fs/create-sym-link target source)
      (cond-> (update counts :updated inc)
        backed-up? (update :backups inc)))))

(defn link-configs! [repo-root]
  (let [timestamp (.format (LocalDateTime/now)
                           (DateTimeFormatter/ofPattern "yyyyMMddHHmmss"))]
    (reduce (partial link-config! timestamp)
            {:unchanged 0 :updated 0 :backups 0}
            (resolved-link-specs repo-root))))

(defn summary [{:keys [unchanged updated backups]}]
  (format "%d unchanged, %d updated, %d %s."
          unchanged updated backups (if (= backups 1) "backup" "backups")))
