(ns benchmarks.lib.core-test
  (:require [babashka.fs :as fs]
            [benchmarks.lib.core :as b]
            [clojure.test :refer [are deftest is testing use-fixtures]]
            [test.support :as support]))

(use-fixtures :each support/with-temp-dir)

(deftest median-test
  (testing "Odd and even samples produce the central value or central average"
    (are [samples expected] (= expected (b/median samples))
      [3 1 2] 2
      [3 1] 2.0
      [7] 7))
  (testing "An empty sample set cannot produce a measurement"
    (is (thrown-with-msg? clojure.lang.ExceptionInfo #"empty" (b/median [])))))

(deftest number-option-test
  (testing "Measurements must be positive and finite"
    (are [value] (thrown? clojure.lang.ExceptionInfo (b/number-option "sample" value))
      "0" "-1" "NaN" "Infinity" "ERR" nil)
    (is (= 0.000001 (b/number-option "sample" "1e-6")))))

(deftest sample-pair-test
  (testing "The same executable path still receives independent, alternating samples"
    (let [calls (atom 0)]
      (is (= [[1 4] [2 3]] (b/sample-pair! (fn [_] (swap! calls inc)) ["same" "same"] 0 2)))))
  (testing "Warmup measurements are excluded from reported samples"
    (let [calls (atom 0)]
      (is (= [[3] [4]] (b/sample-pair! (fn [_] (swap! calls inc)) ["one" "two"] 1 1))))))

(deftest atomic-write-test
  (testing "A completed report replaces its predecessor without leaving pending files"
    (let [target (support/path "results" "report.txt")]
      (b/atomic-write! target "first")
      (b/atomic-write! target "second")
      (is (= "second" (slurp target)))
      (is (= ["report.txt"] (mapv #(str (fs/file-name %)) (fs/list-dir (fs/parent target))))))))
