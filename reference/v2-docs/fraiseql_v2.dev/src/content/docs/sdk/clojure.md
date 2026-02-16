---
title: Clojure SDK
description: FraiseQL client for Clojure with Leiningen and Ring framework support
---

# Clojure SDK

The FraiseQL Clojure SDK provides functional GraphQL operations, built-in Ring/Compojure integration, and spec-based type validation for robust queries.

## Installation

### Leiningen

```clojure
:dependencies [[dev.fraiseql/fraiseql "1.0.0"]
               [clj-http "3.12.0"]
               [cheshire "5.11.0"]]
```

## Quick Start

```clojure
(ns my-app.core
  (:require [fraiseql.client :as client]
            [cheshire.core :as json]))

(def gql-client (client/new-client
  {:url "https://your-api.fraiseql.dev/graphql"
   :api-key "your-api-key"}))

(def query
  "query {
    users(limit: 10) {
      id
      name
      email
    }
  }")

(defn get-users []
  (let [response (client/query gql-client query)]
    (get-in response [:data :users])))

(defn -main []
  (doseq [user (get-users)]
    (println (str (:name user) " (" (:email user) ")"))))
```

## Data Transformation

```clojure
(def query
  "query { users { id name email } }")

(->> (client/query gql-client query)
     (get-in [:data :users])
     (map #(assoc % :display (str (:name %) " <" (:email %) ">")))
     (mapv :display)
     (clojure.string/join ", "))
```

## Ring/Compojure Integration

```clojure
(ns my-app.routes
  (:require [compojure.core :refer [GET defroutes]]
            [ring.util.response :refer [response]]
            [fraiseql.client :as client]))

(def gql-client (client/new-client {:url "..."}))

(defroutes app-routes
  (GET "/api/users" []
    (response
      (get-in (client/query gql-client "query { users { ... } }")
              [:data :users]))))
```

## Spec-Based Type Validation

```clojure
(require '[clojure.spec.alpha :as s])

(s/def ::id string?)
(s/def ::name string?)
(s/def ::email string?)
(s/def ::user (s/keys :req-un [::id ::name ::email]))
(s/def ::users-response (s/coll-of ::user))

(defn validate-response [response]
  (s/valid? ::users-response (get-in response [:data :users])))
```

## Async Operations

```clojure
(require '[clojure.core.async :as async])

(defn async-query [query-str]
  (let [ch (async/chan)]
    (async/go
      (let [result (client/query gql-client query-str)]
        (async/>! ch result)))
    ch))
```

## Error Handling

```clojure
(try
  (client/query gql-client query)
  (catch Exception e
    (println (str "Error: " (.getMessage e)))))

(defn safe-query [query-str]
  (try+
    (client/query gql-client query-str)
    (catch [:type :validation-error] {:keys [message]}
      (println (str "Validation error: " message)))
    (catch [:type :network-error] {:keys [cause]}
      (println (str "Network error: " cause)))))
```

## Testing

```clojure
(deftest test-get-users
  (is (= 1 (count (get-users)))))

(require '[fraiseql.testing :as testing])

(deftest test-with-mock
  (let [mock-client (testing/mock-client
          {"query { users { id } }"
           {:data {:users [{:id "1"}]}}})]
    (is (client/query mock-client "query { users { id } }"))))
```

## Performance

```clojure
; Connection pooling
(def gql-client (client/new-client
  {:url "..."
   :max-connections 10
   :timeout 30000}))

; Batch queries
(let [results (mapv #(async/<! (async-query %))
                    [query1 query2 query3])]
  results)
```

## Troubleshooting

- **Keywords vs Strings**: Use keywords for map keys
- **Threading**: Use core.async for concurrent queries
- **Spec Validation**: Validate responses with spec

See also: [Ring Integration](/deployment)
`3
`3