(ns benchmarks.lib.power-test
  (:require [babashka.process :as process]
            [benchmarks.lib.core :as b]
            [benchmarks.lib.power :as power]
            [benchmarks.low-power.m4-low-power-benchmark :as low-power]
            [clojure.test :refer [are deftest is testing]]))

(deftest hardware-summary-test
  (testing "Published hardware metadata retains benchmark fields and omits device identifiers"
    (is (= "      Model Name: MacBook Air\n      Chip: Apple M1\n      Memory: 16 GB"
           (low-power/hardware-summary
            "Hardware:\n      Model Name: MacBook Air\n      Chip: Apple M1\n      Memory: 16 GB\n      Serial Number (system): device-id\n      Hardware UUID: device-uuid\n")))))

(deftest throughput-test
  (testing "OpenSSL's kB/s suffix is parsed without changing the numeric units"
    (are [text expected] (= expected (low-power/throughput text))
      "type 8192 bytes\nsha256 3305470.67k\n" 3305470.67
      "  sha256 123.5\n" 123.5))
  (testing "Missing and invalid measurements fail"
    (doseq [text ["" "sha256 0k" "sha256 NaNk" "sha256 nope"]]
      (is (thrown? clojure.lang.ExceptionInfo (low-power/throughput text))))))

(deftest parse-plist-test
  (testing "Apple plist integers, nested dictionaries, and binary metadata parse without JSON conversion"
    (is (= [{:Voltage 12000N :InstantAmperage -1000N :BatteryData {:RemainingCapacity 4000N} :Data "YWJj" :Flag true}]
           (power/parse-plist "<?xml version='1.0'?><!DOCTYPE plist PUBLIC '-//Apple//DTD PLIST 1.0//EN' 'http://www.apple.com/DTDs/PropertyList-1.0.dtd'><plist><array><dict><key>Voltage</key><integer>12000</integer><key>InstantAmperage</key><integer>-1000</integer><key>BatteryData</key><dict><key>RemainingCapacity</key><integer>4000</integer></dict><key>Data</key><data>YWJj</data><key>Flag</key><true/></dict></array></plist>")))))

(deftest parse-mode-test
  (testing "Battery settings are read independently of the AC profile"
    (is (= 1 (power/parse-mode "Battery Power:\n lowpowermode 1\nAC Power:\n lowpowermode 0\n"))))
  (testing "Missing battery settings fail explicitly"
    (is (thrown? clojure.lang.ExceptionInfo (power/parse-mode "AC Power:\n lowpowermode 1\n")))))

(deftest verify-test
  (testing "AC power or a different battery setting invalidates a run"
    (doseq [[source value] [["AC" 0] ["Battery" 1]]]
      (with-redefs [b/output! (fn [command]
                               (if (= "batt" (last command))
                                 (str "Now drawing from '" source " Power'\n")
                                 (str "Battery Power:\n lowpowermode " value "\nAC Power:\n lowpowermode 0\n")))]
        (is (thrown? clojure.lang.ExceptionInfo (power/verify! "normal")))))))

(deftest summarize-test
  (testing "Whole-system watts and capacity deltas retain their units in the legacy JSON schema"
    (let [summary (power/summarize [{:power-w 10.0 :voltage-mv 10000 :raw-capacity-mah 4000}
                                    {:power-w 20.0 :voltage-mv 10000 :raw-capacity-mah 3900}] 3600)
          wire (power/wire-summary summary)]
      (are [key expected] (= expected (get summary key))
        :average-power-w 15.0 :median-power-w 15.0 :estimated-energy-wh-from-samples 15.0
        :capacity-delta-mah 100 :estimated-energy-wh-from-capacity 1.0)
      (is (= 15.0 (get wire "average_power_W")))
      (is (= 10.0 (get-in wire ["samples" 0 "power_W"]))))))

(deftest sample-phase-test
  (testing "Charging during a phase invalidates its samples"
    (with-redefs [power/verify! (constantly 0)
                  power/battery-state! (constantly {:current-ma 1})]
      (is (thrown-with-msg? clojure.lang.ExceptionInfo #"discharging" (power/sample-phase! 1 1 "normal" nil)))))
  (testing "A workload that exits early cannot become a successful load measurement"
    (let [stopped @(process/process "/usr/bin/false")]
      (with-redefs [power/verify! (constantly 0)
                    power/battery-state! (constantly {:current-ma -1})
                    b/elapsed-ms (constantly 0)]
        (is (thrown-with-msg? clojure.lang.ExceptionInfo #"OpenSSL exited" (power/sample-phase! 1 1 "normal" stopped)))))))
