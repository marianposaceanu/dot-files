(ns test.fixtures.benchmarks.chrome
  (:require [benchmarks.lib.core :as b]
            [cheshire.core :as json]
            [clojure.string :as str])
  (:import [java.net ServerSocket]
           [java.io DataInputStream DataOutputStream EOFException]
           [java.util Base64]
           [java.security MessageDigest]))

(defn read-line! [input]
  (loop [bytes []]
    (let [value (.read input)]
      (cond (= -1 value) (throw (EOFException.))
            (= 10 value) (String. (byte-array (remove #{13} bytes)) "UTF-8")
            :else (recur (conj bytes value))))))

(defn request! [input]
  (let [line (read-line! input)]
    (loop [headers {}]
      (let [header (read-line! input)]
        (if (str/blank? header)
          {:line line :headers headers}
          (let [[name value] (str/split header #":\s*" 2)]
            (recur (assoc headers (str/lower-case name) value))))))))

(defn frame! [output opcode final? text]
  (let [bytes (.getBytes text "UTF-8") length (alength bytes)]
    (.writeByte output (bit-or (if final? 128 0) opcode))
    (if (< length 126) (.writeByte output length) (do (.writeByte output 126) (.writeShort output length)))
    (.write output bytes)
    (.flush output)))

(defn read-frame! [input]
  (let [opcode (bit-and (.readUnsignedByte input) 15)
        flags (.readUnsignedByte input)
        size (bit-and flags 127)
        length (case size 126 (.readUnsignedShort input) 127 (.readLong input) size)
        mask (byte-array 4)
        data (byte-array length)]
    (when (pos? (bit-and flags 128)) (.readFully input mask))
    (.readFully input data)
    [opcode (String. (byte-array (map-indexed #(unchecked-byte (bit-xor %2 (aget mask (mod %1 4)))) data)) "UTF-8")]))

(defn websocket! [input output mode]
  (loop []
    (let [[opcode text] (read-frame! input)]
      (when (= opcode 1)
        (let [{:keys [id method]} (json/parse-string text true)
              state {:hash "#summary" :score "42" :valid (not= mode "invalid") :viewport [1200 900]}
              result (if (= method "Runtime.evaluate") {:result {:value state}} {})
              message (json/generate-string {:id id :result result})]
          (case mode
            "disconnect" (frame! output 8 true "")
            "stall" (recur)
            "malformed" (frame! output 1 true "invalid JSON")
            "fragmented" (let [middle (quot (count message) 2)]
                           (frame! output 1 false (subs message 0 middle))
                           (frame! output 0 true (subs message middle))
                           (recur))
            (do (frame! output 1 true message) (recur))))))))

(defn serve! [socket port mode]
  (with-open [socket socket
              input (DataInputStream. (.getInputStream socket))
              output (DataOutputStream. (.getOutputStream socket))]
    (try
      (let [{:keys [line headers]} (request! input)]
        (if (= "websocket" (str/lower-case (get headers "upgrade" "")))
          (if (= mode "connect-stall")
            (Thread/sleep 10000)
            (let [key (str (get headers "sec-websocket-key") "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
                  accept (.encodeToString (Base64/getEncoder) (.digest (MessageDigest/getInstance "SHA-1") (.getBytes key "UTF-8")))]
              (.write output (.getBytes (str "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " accept "\r\n\r\n") "UTF-8"))
              (.flush output)
              (websocket! input output mode)))
          (if (= mode "http-stall")
            (Thread/sleep 10000)
            (let [body (json/generate-string (if (str/includes? line "/json/version")
                                              {:Browser "Fixture Chrome"}
                                              {:webSocketDebuggerUrl (str "ws://127.0.0.1:" port "/devtools")}))]
              (.write output (.getBytes (str "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: " (count body) "\r\n\r\n" body) "UTF-8"))
              (.flush output)))))
      (catch java.io.IOException _ nil))))

(defn -main [& args]
  (if (= ["--version"] (vec args))
    (println "Fixture Chrome")
    (let [profile (some #(when (str/starts-with? % "--user-data-dir=") (subs % (count "--user-data-dir="))) args)
          mode (b/env "FAKE_CDP" "success")]
      (with-open [server (ServerSocket. 0)]
        (let [port (.getLocalPort server)]
          (when-not (= mode "startup-stall")
            (spit (b/path profile "DevToolsActivePort") (str port "\n/devtools\n")))
          (binding [*out* *err*] (println "Ordinary Chrome diagnostic on stderr"))
          (loop []
            (let [connection (.accept server)]
              (future (serve! connection port mode))
              (recur))))))))
