import requests

url = "http://localhost:11434/api/generate"
data = {
    "model": "deepseek-r1:7b",
    "prompt": "Write a haiku about rain",
    "stream": False
}
response = requests.post(url, json=data)
print(response.json()["response"])
