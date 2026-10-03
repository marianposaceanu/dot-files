(ns benchmarks.lib.corpus
  (:require [babashka.fs :as fs]
            [benchmarks.lib.core :as b]
            [clojure.string :as str]))

(defn ripgrep-line [index]
  (str (format "%05d level=info résumé naïve payload=" index)
       "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
       " repeated-search-data-for-native-ripgrep-benchmark"
       (when (zero? (mod index 257)) " NEEDLE_native_rg_7d3f91a2")
       (when (zero? (mod index 509)) " error_code=ERR2048 path=/api/v3/search-index")
       (when (zero? (mod index 769)) " request_id=0123456789abcdef;") "\n"))

(defn ripgrep! [root]
  (when-not (fs/regular-file? (b/path root ".complete"))
    (when (fs/exists? root)
      (b/fail! (str "Refusing to replace an existing incomplete corpus: " root) {:corpus root}))
    (let [block (apply str (map ripgrep-line (range 8192)))
          small (apply str (repeat 8 "ordinary searchable content without the benchmark sentinel\n"))]
      (doseq [index (range 128)]
        (b/write! (b/path root "large" (format "input-%04d.log" index)) block))
      (doseq [index (range 5000)]
        (b/write! (b/path root "small" (format "group-%03d" (quot index 100)) (format "item-%05d.txt" index)) small))
      (b/write! (b/path root ".complete") "ripgrep-native-benchmark-corpus-v1\n")))
  root)

(defn ctags! [root]
  (doseq [index (range 240)]
    (b/write! (b/path root "c" (format "unit_%03d.c" index))
              (str "#include <stdint.h>\n"
                   (apply str (for [j (range 90)] (format "static int native_func_%d_%d(int x) { return x + %d; }\n" index j j))))))
  (doseq [index (range 180)]
    (b/write! (b/path root "ruby" (format "model_%03d.rb" index))
              (str "class NativeModel" index "\n"
                   (apply str (for [j (range 70)] (format "  def parser_method_%d_%d(value)\n    value + %d\n  end\n" index j j))) "end\n")))
  (doseq [index (range 160)]
    (b/write! (b/path root "data" (format "object_%03d.json" index))
              (format "{\"name\":\"object_%d\",\"items\":[%s]}\n" index (str/join "," (range 300))))
    (b/write! (b/path root "data" (format "config_%03d.yaml" index))
              (str (format "service_%d:\n  enabled: true\n  routes:\n" index)
                   (apply str (for [j (range 120)] (format "    route_%d: /api/%d/%d\n" j index j))))))
  (doseq [index (range 120)]
    (b/write! (b/path root "mixed" (format "header_%03d.h" index)) (format "typedef struct Native%d { int value; } Native%d;\n" index index))
    (b/write! (b/path root "mixed" (format "script_%03d.rb" index)) (format "module Mixed%d\n  VALUE = %d\nend\n" index index))
    (b/write! (b/path root "mixed" (format "package_%03d.json" index)) (format "{\"package_%d\":{\"version\":\"1.0\"}}\n" index))
    (b/write! (b/path root "mixed" (format "document_%03d.yaml" index)) (format "document_%d:\n  title: native benchmark\n" index)))
  root)

(defn vim-words [count]
  (let [random (java.util.Random. 31337)]
    (apply str (repeatedly count #(str (apply str (repeatedly (+ 4 (.nextInt random 9)) (fn [] (char (+ 97 (.nextInt random 26)))))) "\n")))))

(defn vim-ruby []
  (str "# frozen_string_literal: true\nrequire \"json\"\nrequire \"logger\"\nrequire \"ostruct\"\n\n"
       (apply str
              (for [module (range 1 9)]
                (str "module Service" module "\n  TIMEOUT = 90\n  DEFAULT_RETRIES = 3\n  VERSION = \"1.2.3\".freeze\n"
                     (apply str
                            (for [class (range 1 7)]
                              (str "  class Record" class "Processor\n    include Comparable\n    include Enumerable\n"
                                   "    attr_accessor :record_id, :record_state, :created_at\n    attr_reader :logger, :options\n"
                                   "    def initialize(record_id, options = {})\n      @record_id = record_id\n      @options = options.freeze\n"
                                   "      @logger = Logger.new($stdout, level: :info)\n      @created_at = Time.now\n      @record_state = :pending\n    end\n\n"
                                   (apply str
                                          (for [verb ["process" "transform" "compute" "validate"]]
                                            (str "    def " verb "_record(input, timeout: TIMEOUT)\n"
                                                 "      logger.info(\"Starting #{record_id} (state=#{record_state})\")\n"
                                                 "      raise ArgumentError, \"nil input\" if input.nil?\n\n      result = input\n"
                                                 "        .reject { |item| item.nil? || item.empty? rescue false }\n"
                                                 "        .map { |item| item.to_s.strip.downcase }\n"
                                                 "        .select { |item| item =~ /\\A[a-z][\\w\\-]{0,40}\\z/ }\n        .uniq\n\n"
                                                 "      @record_state = :completed\n      logger.debug(\"Done: #{result.size} items\")\n"
                                                 "      result\n    rescue => e\n      logger.error(\"Failed: #{e.class} — #{e.message}\")\n      raise\n    end\n\n")))
                                   "    def summary\n      <<~SUMMARY\n        ID: #{record_id}\n        State: #{record_state}\n"
                                   "        Created: #{created_at.strftime(\"%Y-%m-%d %H:%M:%S\")}\n        Options: #{options.inspect}\n      SUMMARY\n    end\n\n"
                                   "    def <=>(other)\n      [record_state, created_at] <=> [other.record_state, other.created_at]\n    end\n  end\n\n")))
                     "end\n\n")))
       "# Configuration DSL\n"
       (apply str (for [index (range 1 21)]
                    (str "configure :record do |c|\n  c.timeout = 60\n  c.retries = 3\n  c.log_level = :warn\n"
                         "  c.tags = %w[alpha beta gamma delta epsilon zeta].sample(3)\n"
                         "  c.on_error { |e| warn \"[config-" index "] #{e.message}\" }\nend\n\n")))))

(defn vim! [root]
  (let [words (b/path root "words_100k.txt") ruby (b/path root "code_4k.rb")]
    (when-not (and (fs/regular-file? words) (fs/regular-file? ruby))
      (b/write! words (vim-words 100000))
      (b/write! ruby (vim-ruby)))
    {:words words :ruby ruby}))
