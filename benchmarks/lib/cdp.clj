(ns benchmarks.lib.cdp
  (:require [benchmarks.lib.core :as b]
            [cheshire.core :as json])
  (:import [java.net URI]
           [java.net.http HttpClient WebSocket$Listener]
           [java.util.concurrent TimeUnit]))

(defn remaining [deadline]
  (let [ms (- deadline (System/currentTimeMillis))]
    (when-not (pos? ms) (b/fail! "Speedometer timed out" {}))
    ms))

(defn fail-pending! [{:keys [pending closed]} error]
  (reset! closed error)
  (let [[waiters _] (swap-vals! pending (constantly {}))]
    (doseq [waiter (vals waiters)] (deliver waiter {:error error}))))

(defn receive! [{:keys [pending]} text]
  (let [{:keys [id result error]} (json/parse-string text true)]
    (when-let [waiter (get @pending id)]
      (swap! pending dissoc id)
      (deliver waiter (if error {:error (ex-info (:message error) error)} {:result result})))))

(defn listener [connection]
  (let [fragments (atom "")]
    (reify WebSocket$Listener
      (onOpen [_ socket] (.request socket 1))
      (onText [_ socket text last?]
        (swap! fragments str text)
        (when last?
          (let [[message _] (swap-vals! fragments (constantly ""))]
            (try (receive! connection message)
                 (catch Exception error (fail-pending! connection error)))))
        (.request socket 1)
        nil)
      (onPing [_ socket _] (.request socket 1) nil)
      (onPong [_ socket _] (.request socket 1) nil)
      (onClose [_ _ status reason]
        (fail-pending! connection (ex-info "Chrome DevTools connection closed" {:status status :reason reason}))
        nil)
      (onError [_ _ error]
        (fail-pending! connection (ex-info "Chrome DevTools connection closed" {} error))))))

(defn connect! [url deadline request-timeout]
  (let [client (HttpClient/newHttpClient)
        connection {:client client :pending (atom {}) :closed (atom nil) :next-id (atom 0)
                    :deadline deadline :request-timeout request-timeout}]
    (try
      (assoc connection :socket
             (.get (.buildAsync (.newWebSocketBuilder client) (URI/create url) (listener connection))
                   (long (min request-timeout (remaining deadline))) TimeUnit/MILLISECONDS))
      (catch Exception error (.shutdownNow client) (throw error)))))

(defn request! [{:keys [socket pending closed next-id deadline request-timeout]} method params]
  (when-let [error @closed] (throw error))
  (let [id (swap! next-id inc) waiter (promise)
        expires (+ (System/currentTimeMillis) (min request-timeout (remaining deadline)))]
    (swap! pending assoc id waiter)
    (try
      ;; Recheck after registration so a disconnect cannot strand a new waiter.
      (when-let [error @closed] (throw error))
      (.get (.sendText socket (json/generate-string {:id id :method method :params params}) true)
            (long (remaining expires)) TimeUnit/MILLISECONDS)
      (let [response (deref waiter (long (remaining expires)) ::timeout)]
        (when (= ::timeout response) (b/fail! (str "DevTools request timed out: " method) {:method method}))
        (when-let [error (:error response)] (throw error))
        (:result response))
      (finally (swap! pending dissoc id)))))

(defn close! [{:keys [socket client] :as connection}]
  (fail-pending! connection (ex-info "DevTools connection finished" {}))
  (.abort socket)
  (.shutdownNow client))
