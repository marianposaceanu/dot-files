(ns bootstrap.lib.ruby-warnings-test
  (:require [bootstrap.lib.common :as common]
            [bootstrap.lib.ruby-warnings :as warnings]
            [clojure.string :as str]
            [clojure.test :refer [are deftest is testing]]))

(def ^:private runtime {:label "Test Ruby" :ruby "/bin/sh"})
(def ^:private native-warning
  "Ignoring bcrypt-3.1.22 because its extensions are not built. Try: gem pristine bcrypt --version 3.1.22\n")

(deftest run-test
  (testing "Native-extension warnings are collected once while other diagnostics remain visible"
    (let [collected (atom {})
          stderr (java.io.StringWriter.)]
      (binding [*err* stderr]
        (with-redefs [common/run! (fn [_ _] {:exit 0 :err (str native-warning "Other diagnostic\n")})]
          (warnings/run! collected runtime ["check.rb"])
          (warnings/run! collected (assoc runtime :label "Same Ruby") ["check.rb"])))
      (is (= 1 (count @collected)))
      (is (= #{"bcrypt-3.1.22"} (set (:gems (first (vals @collected))))))
      (is (= "Other diagnostic\nOther diagnostic\n" (str stderr)))))
  (testing "Failed checks throw and preserve both diagnostics and collected warnings"
    (let [collected (atom {})
          stderr (java.io.StringWriter.)]
      (binding [*err* stderr]
        (with-redefs [common/run! (fn [_ _] {:exit 7 :err (str native-warning "Fatal error\n")})]
          (is (thrown-with-msg? clojure.lang.ExceptionInfo #"exit 7"
                                (warnings/run! collected runtime ["check.rb"])))))
      (is (= "Fatal error\n" (str stderr)))
      (is (= #{"bcrypt-3.1.22"} (set (:gems (first (vals @collected))))))))
  (testing "Captured test output is replayed only on failure"
    (doseq [exit-code [0 1]]
      (testing (str "Exit status " exit-code)
        (let [collected (atom {})
              stderr (java.io.StringWriter.)
              stdout (java.io.StringWriter.)
              options (atom nil)
              test-output "Run options: --seed 123\n7 runs, 115 assertions\n"
              result (binding [*out* stdout *err* stderr]
                       (with-redefs [common/run! (fn [opts _]
                                                  (reset! options opts)
                                                  {:exit exit-code :out test-output :err native-warning})]
                         (try
                           (warnings/run! collected runtime {:out :string} ["test.rb"])
                           (catch clojure.lang.ExceptionInfo error
                             error))))]
          (is (= "" (str stdout)))
          (is (= :string (:out @options)))
          (is (= (pos? exit-code) (instance? clojure.lang.ExceptionInfo result)))
          (is (= exit-code (:exit (if (instance? clojure.lang.ExceptionInfo result)
                                   (ex-data result)
                                   result))))
          (is (= (if (zero? exit-code) "" test-output) (str stderr)))
          (is (= #{"bcrypt-3.1.22"} (set (:gems (first (vals @collected)))))))))))

(deftest repair-command-test
  (testing "RVM gem paths are explicitly set and safely quoted"
    (let [rvm (assoc runtime :gem-home "/tmp/RVM gems" :gem-path "/tmp/RVM gems:/tmp/global")
          command (warnings/repair-command rvm)]
      (are [fragment] (str/includes? command fragment)
        "'GEM_HOME=/tmp/RVM gems'"
        "'GEM_PATH=/tmp/RVM gems:/tmp/global'")))
  (testing "A Ruby without a configured gem environment clears inherited gem paths"
    (is (= "env -u GEM_HOME -u GEM_PATH /bin/sh /bin/gem pristine --all --only-missing-extensions"
           (warnings/repair-command runtime)))))

(deftest inspect-test
  (testing "Inactive RVM installations are probed with their own gem environment"
    (let [collected (atom {})
          rvm (assoc runtime :label "RVM Ruby" :gem-home "/tmp/gems")]
      (with-redefs [warnings/runtimes (constantly [runtime rvm])
                    common/result (fn [command]
                                    {:exit 0 :err ""
                                     :out (if (some #{"GEM_HOME=/tmp/gems"} command)
                                            "json-2.21.2\n" "")})]
        (warnings/inspect! collected))
      (is (= #{"json-2.21.2"} (set (:gems (first (vals @collected))))))
      (is (= [rvm] (mapv :runtime (vals @collected))))))
  (testing "Distinct gem environments and failed probes produce separate entries"
    (let [collected (atom {})
          other (assoc runtime :gem-home "/tmp/other-gems")]
      (with-redefs [warnings/runtimes (constantly [runtime other])
                    common/result (constantly {:exit 0 :out "json-2.21.2\n" :err ""})]
        (warnings/inspect! collected))
      (with-redefs [warnings/runtimes (constantly [runtime])
                    common/result (constantly {:exit 7 :out "" :err "broken runtime"})]
        (warnings/inspect! collected))
      (is (= 3 (count @collected)))
      (is (= #{runtime other (assoc runtime :probe-failed? true)}
             (set (map :runtime (vals @collected)))))
      (is (= #{"Could not inspect gems: broken runtime"}
             (->> (vals @collected)
                  (filter (comp :probe-failed? :runtime))
                  first :gems set))))))

(deftest report-test
  (testing "An empty warning collection produces no report"
    (is (= "" (with-out-str (warnings/report! (atom {}))))))
  (testing "The report distinguishes extension repairs from failed runtime probes"
    (let [collected (atom {:extensions {:runtime runtime :gems #{"bcrypt-3.1.22"}}
                           :probe {:runtime (assoc runtime :probe-failed? true)
                                   :gems #{"Could not inspect gems: broken runtime"}}})
          report (with-out-str (warnings/report! collected))]
      (are [fragment] (str/includes? report fragment)
        "RUBY ENVIRONMENT WARNINGS"
        "bcrypt-3.1.22"
        "pristine --all --only-missing-extensions"
        "Could not inspect gems: broken runtime"
        "Next step: check this Ruby installation and its gem environment."))))
