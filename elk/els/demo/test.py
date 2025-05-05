from elasticsearch import Elasticsearch
import json

# Define Elasticsearch hosts
hosts = ["http://localhost:9201", "http://localhost:9202", "http://localhost:9203"]
es = Elasticsearch(hosts=hosts)

try:
    # Perform the search
    response = es.search(index="restaurant_management_2", query={"match_all": {}})
    
    # Convert to dict before serializing
    response_dict = response.body if hasattr(response, 'body') else response
    print(json.dumps(response_dict, indent=4))

except Exception as e:
    print(f"An error occurred: {e}")

