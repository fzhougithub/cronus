package main

import (
  "log"
  "github.com/elastic/go-elasticsearch/v8"
)

func main() {
  cfg := elasticsearch.Config{
    Addresses: []string{"http://192.168.1.168:9201"}, // Elasticsearch server URL
    // Add credentials if needed:
    // Username: "user",
    // Password: "pass",
  }
  es, err := elasticsearch.NewClient(cfg)
  if err != nil {
    log.Fatalf("Error creating client: %s", err)
  }
  log.Println(es.Info()) // Check connection
}

