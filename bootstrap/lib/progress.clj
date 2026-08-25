(ns bootstrap.lib.progress
  (:require [babashka.process :as process])
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
    (let [percent (min 100 (quot (* completed 100) total))]
      (swap! terminal-state assoc :percent percent)
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
