(ns test.runner
  (:require [clojure.test :as test]))

(def unit-test-namespaces
  '[bootstrap.lib.progress-test
    bootstrap.lib.ruby-warnings-test
    benchmarks.lib.core-test
    benchmarks.lib.startup-test
    benchmarks.lib.power-test
    benchmarks.vim-bench-test])

(def integration-test-namespaces
  '[integration.install-macos-test
    integration.editor-config-test
    integration.benchmarks-test])

(def test-namespaces
  (into unit-test-namespaces integration-test-namespaces))

(defn -main
  "Run selected test namespaces and return a failing process status on failure."
  [& namespaces]
  (let [selected (if (seq namespaces) (mapv symbol namespaces) test-namespaces)]
    (doseq [namespace selected]
      (when-not (some #{namespace} test-namespaces)
        (throw (ex-info (str "Unknown test namespace: " namespace)
                        {:namespace namespace :available test-namespaces}))))
    (apply require selected)
    (let [{:keys [fail error]} (apply test/run-tests selected)]
      (when (pos? (+ fail error))
        (System/exit 1)))))
