(ns benchmarks.low-power.m4-low-power-benchmark
  (:refer-clojure :exclude [run!])
  (:require [benchmarks.lib.core :as b]
            [benchmarks.lib.power :as power]
            [benchmarks.low-power.speedometer-runner :as speedometer]
            [cheshire.core :as json]
            [clojure.string :as str]))

(defn throughput [text]
  (let [line (some #(when (re-find #"^\s*sha256\s" %) %) (str/split-lines text))
        value (last (str/split (str/trim (or line "")) #"\s+"))]
    (b/number-option "SHA-256 throughput" (str/replace value #"k$" ""))))

(defn hardware-summary [text]
  (->> (str/split-lines text)
       (filter #(re-find #"^\s*(Model Name|Model Identifier|Chip|Total Number of Cores|Memory):" %))
       (str/join "\n")))

(defn run! [mode iterations]
  (let [actual (power/verify! mode)
        browser-options (speedometer/options iterations)
        started (b/now)
        environment (str "mode=" mode "\nbattery_lowpowermode=" actual "\nstarted=" started "\n"
                         "macos=" (str/trim (b/output! ["sw_vers" "-productVersion"])) " build=" (str/trim (b/output! ["sw_vers" "-buildVersion"])) "\n"
                         (hardware-summary (b/output! ["system_profiler" "SPHardwareDataType"])) "\n"
                         (b/output! [(:chrome browser-options) "--version"])
                         (b/output! ["openssl" "version"])
                         "babashka=" (System/getProperty "babashka.version") "\n"
                         (b/output! ["pmset" "-g" "batt"]) (b/output! ["pmset" "-g" "therm"]))
        runs (mapv (fn [index]
                     (power/verify! mode)
                     (let [{:keys [out err]} (b/capture! ["openssl" "speed" "-seconds" "5" "-bytes" "8192" "-evp" "sha256"])
                           speed (throughput (str out err))]
                       (power/verify! mode)
                       (str "sha256_run=" (inc index) " sha256_8192_kBps=" speed "\n"))) (range 3))
        _ (power/verify! mode)
        browser (speedometer/run! browser-options)]
    (power/verify! mode)
    (str environment (apply str runs) (json/generate-string browser) "\nfinished=" (b/now) "\n")))

(defn -main [& args]
  (if (= ["--help"] (vec args))
    (println "Usage: bb benchmarks/low_power/m4_low_power_benchmark.clj normal|low [iterations]")
    (let [[mode iterations] args]
      (when-not (<= 1 (count args) 2) (b/fail! "Expected mode and optional iterations" {:args args}))
      (power/mode-value mode)
      (let [result (run! mode (or iterations "5"))
            target (b/path b/bench-root "results" (str "m4-low-power-" mode "-" (b/timestamp) ".txt"))]
        (b/atomic-write! target result)
        (print result)
        (println "\nSaved" target)))))

(b/run-cli! -main)
