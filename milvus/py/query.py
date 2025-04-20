res = client.query(
    collection_name="demo_collection",
    filter="subject == 'history'",
    output_fields=["text", "subject"],
)

res = client.query(
    collection_name="demo_collection",
    ids=[0, 2],
    output_fields=["vector", "text", "subject"],
)

