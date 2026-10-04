(ns benchmarks.low-power.speedometer-runner
  (:refer-clojure :exclude [run!])
  (:require [babashka.fs :as fs]
            [babashka.http-client :as http]
            [babashka.process :as process]
            [benchmarks.lib.cdp :as cdp]
            [benchmarks.lib.core :as b]
            [cheshire.core :as json]
            [clojure.string :as str])
  (:import [java.net URLEncoder]))

(def chrome-flags
  ["--headless=new" "--remote-debugging-port=0" "--window-size=1200,900" "--no-first-run"
   "--disable-default-apps" "--disable-extensions" "--disable-sync" "--disable-component-update"
   "--disable-background-timer-throttling" "--disable-backgrounding-occluded-windows" "--disable-renderer-backgrounding" "about:blank"])

(def page-state
  "({ready: document.readyState, hash: location.hash,
     score: document.querySelector('#result-number')?.textContent.trim() || '',
     confidence: document.querySelector('#confidence-number')?.textContent.trim() || '',
     valid: document.querySelector('#summary')?.classList.contains('valid') || false,
     progress: document.querySelector('#progress-completed')?.value || 0,
     progressMax: document.querySelector('#progress-completed')?.max || 0,
     iterationScores: globalThis.benchmarkClient?._measuredValuesList?.map(value => value.score) || [],
     userAgent: navigator.userAgent, viewport: [innerWidth, innerHeight]})")

(defn options [iterations]
  {:iterations (b/integer-option "Iteration count" (or iterations "5") 1)
   :chrome (b/executable (b/env "CHROME_BIN" "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"))
   :timeout (b/integer-option "Timeout" (b/env "SPEEDOMETER_TIMEOUT_MS" "900000") 1)
   :request-timeout (b/integer-option "Request timeout" (b/env "SPEEDOMETER_REQUEST_TIMEOUT_MS" "30000") 1)})

(defn fetch-json! [url method deadline request-timeout]
  (let [{:keys [status body]} (http/request {:uri url :method method :timeout (min request-timeout (cdp/remaining deadline))})]
    (when-not (= 200 status) (b/fail! "DevTools HTTP failure" {:status status :url url}))
    (json/parse-string body true)))

(defn endpoint! [child profile deadline request-timeout]
  (let [port-file (b/path profile "DevToolsActivePort")]
    (loop []
      (cdp/remaining deadline)
      (when-not (.isAlive (:proc child))
        (b/fail! "Chrome exited before DevTools was ready" (select-keys @child [:exit :err])))
      (if (fs/regular-file? port-file)
        (let [port (b/integer-option "DevTools port" (first (str/split-lines (slurp port-file))) 1)
              base (str "http://127.0.0.1:" port)]
          {:base base :version (fetch-json! (str base "/json/version") :get deadline request-timeout)})
        (do (Thread/sleep (min 100 (cdp/remaining deadline))) (recur))))))

(defn valid-result! [state]
  (when-not (:valid state) (b/fail! "Invalid Speedometer result" {:state state}))
  (b/number-option "Speedometer score" (:score state))
  state)

(defn measure! [connection]
  (loop []
    (cdp/remaining (:deadline connection))
    (let [response (cdp/request! connection "Runtime.evaluate" {:expression page-state :returnByValue true :awaitPromise true})
          _ (when-let [error (:exceptionDetails response)] (b/fail! "Page evaluation failed" error))
          state (get-in response [:result :value])]
      (if (and (= "#summary" (:hash state)) (seq (:score state)))
        (valid-result! state)
        (do (Thread/sleep (min 1000 (cdp/remaining (:deadline connection)))) (recur))))))

(defn run! [{:keys [chrome iterations timeout request-timeout]}]
  (b/with-temp-dir
   (fn [profile]
     (let [started (b/now) deadline (+ (System/currentTimeMillis) timeout)
           child (apply process/process {:out :string :err :string} (into [chrome (str "--user-data-dir=" profile)] chrome-flags))]
       (try
         (let [{:keys [base version]} (endpoint! child profile deadline request-timeout)
               target (fetch-json! (str base "/json/new?" (URLEncoder/encode "about:blank" "UTF-8")) :put deadline request-timeout)
               connection (cdp/connect! (:webSocketDebuggerUrl target) deadline request-timeout)
               url (str "https://browserbench.org/Speedometer3.1/?startAutomatically&iterationCount=" iterations "&viewport=1200x900")]
           (try
             (cdp/request! connection "Runtime.enable" {})
             (cdp/request! connection "Emulation.setDeviceMetricsOverride" {:width 1200 :height 900 :deviceScaleFactor 1 :mobile false})
             (when-let [error (:errorText (cdp/request! connection "Page.navigate" {:url url}))]
               (b/fail! "Speedometer navigation failed" {:error error}))
             (merge {:startedAt started :finishedAt nil :iterations iterations :executablePath chrome :browserVersion version :benchmarkURL url}
                    (measure! connection) {:finishedAt (b/now)})
             (finally (cdp/close! connection))))
         (finally (b/stop-process! child)))))))

(defn -main [& args]
  (if (= ["--help"] (vec args))
    (println "Usage: bb benchmarks/low_power/speedometer_runner.clj [iterations]")
    (do
      (when (> (count args) 1) (b/fail! "Expected at most one iteration count" {:args args}))
      (println (json/generate-string (run! (options (first args))))))))

(b/run-cli! -main)
