(ns benchmarks.lib.power
  (:require [benchmarks.lib.core :as b]
            [clojure.data.xml :as xml]
            [clojure.string :as str]))

(defn mode-value [mode]
  (case mode "normal" 0 "low" 1 (b/fail! "Expected battery mode normal or low" {:mode mode})))

(defn parse-mode [text]
  (let [section (some-> text (str/split #"Battery Power:" 2) second (str/split #"AC Power:" 2) first)
        value (some->> section (re-find #"lowpowermode\s+(\d+)") second parse-long)]
    (when-not (#{0 1} value) (b/fail! "Could not read battery Low Power Mode" {:output text}))
    value))

(defn verify! [mode]
  (let [expected (mode-value mode)
        battery (b/output! ["pmset" "-g" "batt"])
        actual (parse-mode (b/output! ["pmset" "-g" "custom"]))]
    (when-not (str/includes? (or (first (str/split-lines battery)) "") "Now drawing from 'Battery Power'")
      (b/fail! "Disconnect AC power before benchmarking battery modes" {}))
    (when-not (= expected actual) (b/fail! "Battery Low Power Mode changed or does not match the requested mode" {:expected expected :actual actual}))
    actual))

(defn plist-value [{:keys [tag content]}]
  (let [text (apply str (filter string? content))
        elements (filter map? content)]
    (case (keyword (name tag))
      :plist (plist-value (first elements))
      :array (mapv plist-value elements)
      :dict (into {} (map (fn [[key value]] [(keyword (apply str (:content key))) (plist-value value)]))
                  (partition 2 elements))
      :integer (bigint (str/trim text))
      :real (Double/parseDouble (str/trim text))
      :true true
      :false false
      :string text
      :data text
      :date text
      (b/fail! "Unsupported plist element" {:tag tag}))))

(defn parse-plist [text]
  (plist-value (xml/parse-str text :support-dtd false)))

(defn battery-state! []
  (let [plist (b/output! ["ioreg" "-r" "-n" "AppleSmartBattery" "-a"])
        battery (first (parse-plist plist))
        current (:InstantAmperage battery) voltage (:Voltage battery)
        capacity (or (:AppleRawCurrentCapacity battery) (get-in battery [:BatteryData :RemainingCapacity]))
        maximum (or (:AppleRawMaxCapacity battery) (get-in battery [:BatteryData :FullChargeCapacity]))]
    (when-not (every? number? [current voltage capacity maximum])
      (b/fail! "Required AppleSmartBattery telemetry is unavailable" {}))
    {:timestamp (b/now) :monotonic (/ (b/elapsed-ms) 1000.0)
     :current-ma current :voltage-mv voltage :power-w (/ (* (abs current) voltage) 1000000.0)
     :raw-capacity-mah capacity :raw-max-capacity-mah maximum
     :capacity-source (if (:AppleRawCurrentCapacity battery) "AppleRawCurrentCapacity" "BatteryData.RemainingCapacity")
     :temperature-c (some-> (:Temperature battery) (/ 100.0)) :telemetry-system-load-mw (get-in battery [:PowerTelemetryData :SystemLoad])}))

(defn summarize [samples elapsed]
  (when (empty? samples) (b/fail! "Battery phase has no samples" {}))
  (let [watts (map :power-w samples)
        delta (- (:raw-capacity-mah (first samples)) (:raw-capacity-mah (last samples)))
        voltage (/ (b/mean (map :voltage-mv samples)) 1000.0)]
    {:elapsed-seconds elapsed :sample-count (count samples)
     :average-power-w (b/mean watts) :median-power-w (b/median watts)
     :minimum-power-w (apply min watts) :maximum-power-w (apply max watts)
     :estimated-energy-wh-from-samples (/ (* (b/mean watts) elapsed) 3600.0)
     :capacity-delta-mah delta :estimated-energy-wh-from-capacity (/ (* delta voltage) 1000.0)
     :start-capacity-mah (:raw-capacity-mah (first samples)) :finish-capacity-mah (:raw-capacity-mah (last samples))
     :samples samples}))

(defn sleep! [milliseconds] (Thread/sleep (long milliseconds)))

(defn sample-phase! [duration interval mode child]
  (let [started (b/elapsed-ms)]
    (loop [samples []]
      (verify! mode)
      (let [state (battery-state!) elapsed (- (b/elapsed-ms) started) samples (conj samples state)]
        (when-not (neg? (:current-ma state)) (b/fail! "The Mac must be discharging on battery power" {}))
        (if (>= elapsed (* duration 1000))
          (summarize samples (/ elapsed 1000.0))
          (do
            (when (and child (not (.isAlive (:proc child))))
              (b/fail! "OpenSSL exited before the measurement phase completed" {}))
            (sleep! (min (* interval 1000) (- (* duration 1000) elapsed)))
            (recur samples)))))))

(def state-keys
  {:capacity-source "capacity_source" :current-ma "current_mA" :voltage-mv "voltage_mV" :power-w "power_W" :raw-capacity-mah "raw_capacity_mAh"
   :raw-max-capacity-mah "raw_max_capacity_mAh" :temperature-c "temperature_C" :telemetry-system-load-mw "telemetry_system_load_mW"})
(def summary-keys
  {:elapsed-seconds "elapsed_seconds" :sample-count "sample_count" :average-power-w "average_power_W" :median-power-w "median_power_W"
   :minimum-power-w "minimum_power_W" :maximum-power-w "maximum_power_W" :estimated-energy-wh-from-samples "estimated_energy_Wh_from_samples"
   :capacity-delta-mah "capacity_delta_mAh" :estimated-energy-wh-from-capacity "estimated_energy_Wh_from_capacity"
   :start-capacity-mah "start_capacity_mAh" :finish-capacity-mah "finish_capacity_mAh"})

(defn wire-keys [mapping value]
  (into {} (map (fn [[key value]] [(get mapping key (name key)) value])) value))

(defn wire-summary [summary]
  (-> (wire-keys summary-keys summary)
      (assoc "samples" (mapv #(wire-keys state-keys %) (:samples summary)))))
