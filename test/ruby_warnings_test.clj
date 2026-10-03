(require '[babashka.classpath :as classpath]
         '[babashka.fs :as fs])
(classpath/add-classpath (str (fs/parent (fs/parent (fs/canonicalize *file*)))))
(ns ruby-warnings-test
  (:require [bootstrap.lib.common :as common]
            [bootstrap.lib.ruby-warnings :as warnings]
            [clojure.string :as str]
            [clojure.test :as test :refer [deftest is testing]]))

(def runtime {:label "Test Ruby" :ruby "/bin/sh"})
(def native-warning
  "Ignoring bcrypt-3.1.22 because its extensions are not built. Try: gem pristine bcrypt --version 3.1.22\n")

(deftest collects-and-deduplicates-without-hiding-other-stderr
  (let [collected (atom {})
        stderr (java.io.StringWriter.)]
    (binding [*err* stderr]
      (with-redefs [common/run! (fn [_ _] {:exit 0 :err (str native-warning "Other diagnostic\n")})]
        (warnings/run! collected runtime ["check.rb"])
        (warnings/run! collected (assoc runtime :label "Same Ruby") ["check.rb"])))
    (is (= 1 (count @collected)))
    (is (= #{"bcrypt-3.1.22"} (set (first (vals @collected)))))
    (is (= "Other diagnostic\nOther diagnostic\n" (str stderr)))
    (let [report (with-out-str (warnings/report! collected))]
      (is (str/includes? report "RUBY ENVIRONMENT WARNINGS"))
      (is (str/includes? report "pristine --all --only-missing-extensions")))))

(deftest preserves-check-failures-and-collected-warnings
  (let [collected (atom {})
        stderr (java.io.StringWriter.)]
    (binding [*err* stderr]
      (with-redefs [common/run! (fn [_ _] {:exit 7 :err (str native-warning "Fatal error\n")})]
        (is (thrown-with-msg? clojure.lang.ExceptionInfo #"exit 7"
                              (warnings/run! collected runtime ["check.rb"])))))
    (is (= "Fatal error\n" (str stderr)))
    (is (= #{"bcrypt-3.1.22"} (set (get @collected runtime))))))

(deftest isolates-rvm-repair-environments
  (let [rvm (assoc runtime :gem-home "/tmp/RVM gems" :gem-path "/tmp/RVM gems:/tmp/global")
        command (warnings/repair-command rvm)]
    (is (str/includes? command "'GEM_HOME=/tmp/RVM gems'"))
    (is (str/includes? command "'GEM_PATH=/tmp/RVM gems:/tmp/global'"))
    (is (= "" (with-out-str (warnings/report! (atom {})))))))

(deftest quiet-test-runs-replay-output-only-on-failure
  (doseq [exit [0 1]]
    (testing (str "exit " exit)
      (let [collected (atom {})
            stderr (java.io.StringWriter.)
            options (atom nil)
            failure (atom nil)
            test-output "Run options: --seed 123\n7 runs, 115 assertions\n"]
        (binding [*err* stderr]
          (with-redefs [common/run! (fn [opts _]
                                     (reset! options opts)
                                     {:exit exit :out test-output :err native-warning})]
            (is (= "" (with-out-str
                        (try
                          (warnings/run! collected runtime {:out :string} ["test.rb"])
                          (catch clojure.lang.ExceptionInfo error
                            (reset! failure error))))))))
        (is (= :string (:out @options)))
        (is (= (when (pos? exit) exit) (some-> @failure ex-data :exit)))
        (is (= (if (zero? exit) "" test-output) (str stderr)))
        (is (= #{"bcrypt-3.1.22"} (set (get @collected runtime))))))))

(deftest discovers-missing-extensions-in-inactive-rubies
  (let [collected (atom {})
        rvm (assoc runtime :label "RVM Ruby" :gem-home "/tmp/gems")]
    (with-redefs [warnings/runtimes (constantly [runtime rvm])
                  common/result (fn [command]
                                  {:exit 0 :err ""
                                   :out (if (some #{"GEM_HOME=/tmp/gems"} command)
                                          "json-2.21.2\n" "")})]
      (warnings/inspect! collected))
    (is (= #{"json-2.21.2"} (set (get @collected rvm))))
    (is (not (contains? @collected runtime)))))

(let [{:keys [fail error]} (test/run-tests 'ruby-warnings-test)]
  (when (pos? (+ fail error))
    (System/exit 1)))
