(require '[babashka.classpath :as classpath]
         '[babashka.fs :as fs])

(def repo-root
  (-> *file* fs/parent fs/parent fs/canonicalize str))

(classpath/add-classpath repo-root)
(require '[bootstrap.app.install-macos :as installer])

(apply installer/-main *command-line-args*)
