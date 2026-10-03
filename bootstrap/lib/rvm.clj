(ns bootstrap.lib.rvm
  (:require [babashka.fs :as fs]
            [bootstrap.lib.common :as common]
            [bootstrap.lib.progress :as progress]
            [clojure.edn :as edn]
            [clojure.string :as str]))

(defn read-config [path]
  (let [{:keys [rubies default-ruby] :as config} (edn/read-string (slurp (str path)))]
    (when-not (and (vector? rubies)
                   (seq rubies)
                   (every? #(and (string? %) (re-matches #"\d+\.\d+\.\d+" %)) rubies)
                   (= (count rubies) (count (distinct rubies)))
                   (some #{default-ruby} rubies))
      (throw (ex-info "RVM config requires unique, exact Ruby versions and a default from that list."
                      {:path (str path)})))
    config))

(defn root []
  (str (fs/path (or (System/getenv "HOME") (System/getProperty "user.home")) ".rvm")))

(defn- ruby-version [binary]
  (when (fs/executable? binary)
    (let [{:keys [exit out]} (common/result
                            ["env" "-u" "GEM_HOME" "-u" "GEM_PATH"
                             (str binary) "--disable-gems" "-e" "print RUBY_VERSION"])]
      (when (zero? exit)
        (str/trim out)))))

(defn- installed? [rvm-root version]
  (= version (ruby-version (fs/path rvm-root "rubies" (str "ruby-" version) "bin/ruby"))))

(defn- default-version [rvm-root]
  (ruby-version (fs/path rvm-root "rubies/default/bin/ruby")))

(defn- command [rvm-root & args]
  (let [path (->> (str/split (or (System/getenv "PATH") "") #":")
                  (remove #(str/starts-with? % (str rvm-root "/")))
                  (str/join ":"))]
    (into ["env" "-u" "GEM_HOME" "-u" "GEM_PATH" "-u" "MY_RUBY_HOME" "-u" "RUBY_VERSION"
           (str "PATH=" path) (str "rvm_path=" rvm-root)
           "/bin/bash" "--noprofile" "--norc" "-c"
           "source \"$1\" || exit; shift; rvm \"$@\""
           "rvm" (str (fs/path rvm-root "scripts/rvm"))]
          args)))

(defn- ensure-rvm! [rvm-root]
  (when-not (fs/regular-file? (fs/path rvm-root "scripts/rvm"))
    (let [gpg (or (common/command-path "gpg")
                  (throw (ex-info "GPG is required to install RVM; install the repository Brewfile first." {})))]
      (common/info "Installing RVM stable...")
      (common/run! [gpg "--keyserver" "hkps://keyserver.ubuntu.com" "--recv-keys"
                    "409B6B1796C275462A1703113804BB82D39DC0E3"
                    "7D2BAF1CF37B13E2069D6956105BD0E739499BDB"])
      (common/run! {:in (common/capture ["curl" "-fsSL" "https://get.rvm.io"])
                    :extra-env {"rvm_path" rvm-root "rvm_ignore_dotfiles" "yes"}}
                   ["/bin/bash" "-s" "stable" "--ignore-dotfiles" "--path" rvm-root])))
  (when-not (fs/regular-file? (fs/path rvm-root "scripts/rvm"))
    (throw (ex-info "RVM installation completed without its shell entrypoint." {:root rvm-root}))))

(defn status [{:keys [rubies default-ruby]}]
  (let [rvm-root (root)
        hint " Run bb bootstrap/setup/install_rvm.clj."]
    (vec
     (concat
      [(if (fs/regular-file? (fs/path rvm-root "scripts/rvm"))
         {:status :ok :message "RVM is installed."}
         {:status :warn :message (str "RVM is missing." hint)})]
      (for [version rubies]
        (if (installed? rvm-root version)
          {:status :ok :message (str "RVM Ruby " version " is installed and runs.")}
          {:status :warn :message (str "RVM Ruby " version " is missing or does not run correctly." hint)}))
      [(if (= default-ruby (default-version rvm-root))
         {:status :ok :message (str "RVM default Ruby is " default-ruby ".")}
         {:status :warn :message (str "RVM default Ruby should be " default-ruby "." hint)})]))))

(defn install! [{:keys [rubies default-ruby] :as config}]
  (let [rvm-root (root)
        total (+ 3 (count rubies))]
    (ensure-rvm! rvm-root)
    (progress/report! 1 total)
    (doseq [[index version] (map-indexed vector rubies)]
      (if (installed? rvm-root version)
        (common/success (str "RVM Ruby " version " is already installed."))
        (do
          (common/info (str "Installing RVM Ruby " version "..."))
          (common/run! (command rvm-root "install" (str "ruby-" version)))
          (when-not (installed? rvm-root version)
            (throw (ex-info (str "RVM Ruby " version " does not run correctly after installation.")
                            {:version version})))))
      (progress/report! (+ 2 index) total))
    (when-not (= default-ruby (default-version rvm-root))
      (common/info (str "Setting the RVM default to Ruby " default-ruby "..."))
      (common/run! (command rvm-root "--default" "use" (str "ruby-" default-ruby))))
    (progress/report! (+ 2 (count rubies)) total)
    (when-let [problem (first (filter #(= :warn (:status %)) (status config)))]
      (throw (ex-info (:message problem) {})))
    (progress/report! total total)
    (common/success (str "RVM is ready; default Ruby is " default-ruby "."))))
