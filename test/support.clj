(ns test.support
  (:require [babashka.fs :as fs]
            [bootstrap.lib.common :as common]
            [clojure.test :as test]))

(def repo-root (-> *file* fs/canonicalize fs/parent fs/parent str))
(def bb (or (System/getenv "BB_BIN") (common/command-path "bb")))
(def ^:dynamic *temp-dir* nil)

(defn with-temp-dir [test!]
  (let [directory (fs/create-temp-dir {:prefix "dot-files-test-"})]
    (try
      (binding [*temp-dir* (str directory)] (test!))
      (finally (fs/delete-tree directory)))))

(defn path [& parts]
  (str (apply fs/path *temp-dir* parts)))

(defn write-file! [path content]
  (fs/create-dirs (fs/parent path))
  (spit path content)
  path)

(defn executable! [path content]
  (write-file! path content)
  (fs/set-posix-file-permissions path "rwxr-xr-x")
  path)

(defn capture
  ([command] (capture {} command))
  ([opts command]
   (common/run! (merge {:continue true :out :string :err :string} opts) command)))

(defn run-tests! [namespace]
  (let [{:keys [fail error]} (test/run-tests namespace)]
    (when (pos? (+ fail error)) (System/exit 1))))
