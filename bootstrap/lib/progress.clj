(ns bootstrap.lib.progress
  (:require [babashka.fs :as fs]
            [babashka.process :as process]
            [clojure.edn :as edn])
  (:import [sun.misc Signal SignalHandler]))

(def ^:private escape "\u001b")
(def ^:private terminal-lock (Object.))
(def ^:private initial-state
  {:interactive false
   :active false
   :rows nil
   :columns nil
   :percent 0
   :signal nil
   :previous-handler nil
   :shutdown-hook nil})
(def ^:private terminal-state (atom initial-state))

(defn- write-terminal! [& values]
  (print (apply str values))
  (flush))

(defn- interactive-terminal? []
  (and (not= "dumb" (System/getenv "TERM"))
       (zero? (:exit (process/shell {:continue true :err :string}
                                    "/bin/test" "-t" "1")))
       (zero? (:exit (process/shell {:continue true :err :string}
                                    "/bin/test" "-r" "/dev/tty")))))

(defn- terminal-size []
  (let [{:keys [exit out]}
        (process/shell {:continue true :out :string :err :string}
                       "/bin/sh" "-c" "stty size </dev/tty")]
    (when (zero? exit)
      (when-let [[_ rows columns]
                 (re-matches #"\s*(\d+)\s+(\d+)\s*" out)]
        (let [rows (parse-long rows)
              columns (parse-long columns)]
          (when (and (>= rows 3) (pos? columns))
            {:rows rows :columns columns}))))))

(defn- progress-text [{:keys [columns percent]}]
  (let [available (max 1 (- columns 8))
        width (min 50 available)
        filled (quot (* percent width) 100)
        text (format "[%s%s] %3d%%"
                     (apply str (repeat filled \#))
                     (apply str (repeat (- width filled) \space))
                     percent)]
    (subs text 0 (min (count text) (max 1 (dec columns))))))

(defn- draw-progress! []
  (when (:active @terminal-state)
    (let [{:keys [rows] :as current} @terminal-state]
      (write-terminal! escape "7"
                       escape "[" rows ";1H"
                       escape "[2K"
                       (progress-text current)
                       escape "8"))))

(defn- restore-terminal! []
  (when (:active @terminal-state)
    (let [{old-rows :rows} @terminal-state
          {current-rows :rows} (or (terminal-size) {:rows old-rows})
          extra-clear (if (not= old-rows current-rows)
                        (str escape "[" current-rows ";1H" escape "[2K")
                        "")]
      (write-terminal! escape "7"
                       escape "[" old-rows ";1H" escape "[2K"
                       extra-clear
                       escape "8"
                       escape "7"
                       escape "[1;" current-rows "r"
                       escape "8")
      (swap! terminal-state assoc :active false :rows current-rows))))

(defn- reserve-progress-line! [{:keys [rows columns]}]
  (write-terminal! escape "[1;" (dec rows) "r"
                   escape "[" (dec rows) ";1H")
  (swap! terminal-state assoc
         :active true
         :rows rows
         :columns columns)
  (draw-progress!))

(defn- refresh-terminal! []
  (when-let [size (terminal-size)]
    (when (or (not (:active @terminal-state))
              (not= size (select-keys @terminal-state [:rows :columns])))
      (restore-terminal!)
      (reserve-progress-line! size))))

(defn- uninstall-handlers! []
  (let [{:keys [signal previous-handler shutdown-hook]} @terminal-state]
    (when (and signal previous-handler)
      (try
        (Signal/handle signal previous-handler)
        (catch Exception _)))
    (when (and shutdown-hook
               (not= shutdown-hook (Thread/currentThread)))
      (try
        (.removeShutdownHook (Runtime/getRuntime) shutdown-hook)
        (catch Exception _)))
    (swap! terminal-state assoc
           :signal nil
           :previous-handler nil
           :shutdown-hook nil)))

(defn stop! []
  (locking terminal-lock
    (uninstall-handlers!)
    (restore-terminal!)
    (swap! terminal-state assoc :interactive false)))

(defn- install-handlers! []
  (let [signal (Signal. "WINCH")
        handler (reify SignalHandler
                  (handle [_ _]
                    (try
                      (locking terminal-lock
                        (refresh-terminal!)
                        (draw-progress!))
                      (catch Exception _))))
        previous-handler (Signal/handle signal handler)
        shutdown-hook (Thread. ^Runnable (fn [] (stop!)))]
    (.addShutdownHook (Runtime/getRuntime) shutdown-hook)
    (swap! terminal-state assoc
           :signal signal
           :previous-handler previous-handler
           :shutdown-hook shutdown-hook)))

(defn start! []
  (locking terminal-lock
    (reset! terminal-state initial-state)
    (when (interactive-terminal?)
      (when-let [size (terminal-size)]
        (swap! terminal-state assoc :interactive true)
        (reserve-progress-line! size)
        (install-handlers!)))))

(defn update! [completed total]
  (locking terminal-lock
    (let [percent (max 0 (min 99 (long (/ (* completed 100) total))))]
      (swap! terminal-state update :percent max percent)
      (when (:interactive @terminal-state)
        (refresh-terminal!)
        (draw-progress!)))))

(defn complete! []
  (locking terminal-lock
    (swap! terminal-state assoc :percent 100)
    (when (:interactive @terminal-state)
      (refresh-terminal!)
      (draw-progress!))
    (let [text (if (:interactive @terminal-state)
                 (progress-text @terminal-state)
                 "[##################################################] 100%")]
      (uninstall-handlers!)
      (restore-terminal!)
      (println text)
      (swap! terminal-state assoc :interactive false))))

(defn report! [completed total]
  ;; Child scripts publish milestones; only the installer draws the terminal bar.
  (when-let [path (System/getenv "DOT_FILES_PROGRESS_FILE")]
    (let [pending (str path ".pending")]
      (spit pending (pr-str [completed total]))
      (fs/move pending path {:replace-existing true}))))

(defn- read-report [path]
  (when (fs/exists? path)
    (let [report (edn/read-string (slurp path))]
      (when (and (vector? report) (= 2 (count report))
                 (every? number? report) (pos? (second report))
                 (<= 0 (first report) (second report)))
        report))))

(defn run-reporting! [options command on-progress]
  (let [directory (fs/create-temp-dir {:prefix "dot-files-progress-"})
        path (str (fs/path directory "progress.edn"))]
    (try
      (let [child (apply process/process
                         (assoc-in (merge {:in :inherit :out :inherit :err :inherit} options)
                                   [:extra-env "DOT_FILES_PROGRESS_FILE"] path)
                         command)]
        (try
          (loop [previous nil]
            (let [report (read-report path)]
              (when (and report (not= report previous))
                (apply on-progress report))
              (if-let [result (deref child 50 nil)]
                (do
                  (when-let [final-report (read-report path)]
                    (when (not= final-report report)
                      (apply on-progress final-report)))
                  (process/check result))
                (recur report))))
          (finally
            (when (.isAlive (:proc child))
              (process/destroy-tree child)
              @child))))
      (finally
        (fs/delete-tree directory)))))
