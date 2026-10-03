(ns benchmarks.m4-power-benchmark
  (:refer-clojure :exclude [run!])
  (:require [babashka.process :as process]
            [benchmarks.lib.core :as b]
            [benchmarks.lib.power :as power]
            [clojure.string :as str]))

(def duration-flags
  {"--idle-seconds" :idle-seconds "--warmup-seconds" :warmup-seconds "--load-seconds" :load-seconds "--sample-seconds" :sample-seconds})

(defn parse-options [[mode & args]]
  (power/mode-value mode)
  (loop [args args options {:mode mode :idle-seconds 90 :warmup-seconds 60 :load-seconds 180 :sample-seconds 5}]
    (if-let [[flag value & more] (seq args)]
      (if-let [key (get duration-flags flag)]
        (recur more (assoc options key (b/integer-option flag value 1)))
        (b/fail! "Unknown power benchmark argument" {:argument flag}))
      options)))

(defn run! [{:keys [mode idle-seconds warmup-seconds load-seconds sample-seconds]}]
  (let [actual (power/verify! mode)
        idle (power/sample-phase! idle-seconds sample-seconds mode nil)
        command ["openssl" "speed" "-elapsed" "-seconds" (str (+ warmup-seconds load-seconds)) "-bytes" "8192" "-evp" "sha256"]]
    (b/with-temp-dir
     (fn [directory]
       (let [log (b/path directory "openssl.log")
             child (apply process/process {:out :write :out-file log :err :out} command)]
         (try
           (let [warmup (power/sample-phase! warmup-seconds sample-seconds mode child)
                 load (power/sample-phase! load-seconds sample-seconds mode child)
                 finished (deref child 30000 ::timeout)]
             (when (or (= ::timeout finished) (not (zero? (:exit finished))))
               (b/fail! "OpenSSL workload failed or did not finish" {:result finished}))
             {:mode mode :battery_lowpowermode actual
              :started_at (:timestamp (first (:samples idle))) :finished_at (:timestamp (last (:samples load)))
              :sample_interval_seconds sample-seconds :workload_command command :openssl_output (slurp log)
              :idle (power/wire-summary idle) :load_warmup (power/wire-summary warmup) :load (power/wire-summary load)})
           (finally (b/stop-process! child))))))))

(defn -main [& args]
  (if (= ["--help"] (vec args))
    (println "Usage: bb benchmarks/m4_power_benchmark.clj normal|low [--idle-seconds N] [--warmup-seconds N] [--load-seconds N] [--sample-seconds N]")
    (let [options (parse-options args) result (run! options)
          target (b/path b/bench-root "results" (str "m4-power-" (:mode options) "-" (b/timestamp) ".json"))]
      (b/atomic-write! target (b/json-string result))
      (println (b/json-string {:result target :idle_average_W (get-in result [:idle "average_power_W"])
                              :load_average_W (get-in result [:load "average_power_W"])
                              :load_energy_Wh (get-in result [:load "estimated_energy_Wh_from_samples"])
                              :capacity_energy_Wh (get-in result [:load "estimated_energy_Wh_from_capacity"])
                              :openssl_result (last (str/split-lines (:openssl_output result)))})))))

(b/run-cli! -main)
