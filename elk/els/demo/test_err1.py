#pip install "elasticsearch>=8.0.0,<9.0.0" --upgrade

from elasticsearch import Elasticsearch
import json

# Elasticsearch server hosts
hosts = ["http://localhost:9201", "http://localhost:9202", "http://localhost:9203"]
es = Elasticsearch(hosts=hosts)

try:
    response = es.search(index="restaurant_management_2", query={"match_all": {}})
    print(json.dumps(response, indent=4))
except Exception as e:
    print(f"An error occurred: {e}")

