res = client.delete(collection_name="demo_collection", ids=[0, 2])

print(res)

res = client.delete(
    collection_name="demo_collection",
    filter="subject == 'biology'",
)

print(res)

