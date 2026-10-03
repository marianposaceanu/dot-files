(ns benchmarks.vim-bench-test
  (:require [benchmarks.vim-bench :as vim]
            [clojure.test :refer [are deftest is testing]]))

(deftest timing-samples-test
  (testing "Incomplete, corrupt, zero, and nonfinite samples are rejected"
    (are [text runs] (thrown? clojure.lang.ExceptionInfo (vim/timing-samples text runs))
      "1.0\n" 2 "0\n" 1 "ERR\n" 1 "NaN\n" 1 "Infinity\n" 1)
    (is (= [1.0 3.0] (vim/timing-samples "1.0\n3.0\n" 2)))))

(deftest parse-options-test
  (testing "Vim arguments select the intended workflow and validate counts and result labels"
    (is (= {:mode :bench :runs 2 :label "fixture"} (vim/parse-options ["--bench-only" "--runs" "2" "--label" "fixture"])))
    (are [args] (thrown? clojure.lang.ExceptionInfo (vim/parse-options args))
      ["--runs"] ["--runs" "0"] ["--label" "../outside"] ["--compare" "only-one"] ["unknown"])))
