(ns benchmarks.lib.startup-test
  (:require [benchmarks.lib.startup :as startup]
            [clojure.test :refer [deftest is testing]]))

(deftest parse-log-test
  (testing "Nested sourced times remain separate from self time and elapsed startup"
    (let [profile (startup/parse-log (str "001.000 10.000 2.000: sourcing /fixture/.vim/pack/bundles/start/example/plugin/a.vim\n"
                                          "002.000 20.000 3.000: sourcing /fixture/.vim/pack/bundles/start/example/autoload/b.vim\n"
                                          "042.000 001.000: finished\n"))]
      (is (= 42.0 (:total profile)))
      (is (= [{:name "example" :self 5.0 :files 2}] (vec (startup/plugin-totals (:files profile)))))))
  (testing "Malformed logs do not silently become zero-time measurements"
    (is (thrown? clojure.lang.ExceptionInfo (startup/parse-log "missing timestamps")))))

(deftest archived-total-test
  (testing "Only recorded inclusive plugin rows contribute to historical totals"
    (is (= 3.0 (startup/archived-total "Plugin totals under .vim/pack/bundles/start (ms):\n 1.000 2 files alpha\n 2.000 3 files beta\nTip: rerun\n 99.0 1 files unrelated\n")))))
