import argparse
import pymongo
import os
from datetime import datetime

def load_stock_data(mongo_uri, database_name, collection_name, input_file):
    """Loads stock data into a MongoDB collection with updated schema."""

    try:
        client = pymongo.MongoClient(mongo_uri)
        db = client[database_name]
        collection = db[collection_name]

        with open(input_file, 'r') as file:
            for line_num, line in enumerate(file, start=1):
                line = line.strip()
                if not line:
                    continue  # Skip empty lines

                try:
                    # Split the line by comma
                    symbol, date_str, o, h, l, c, amount, v, unknown = line.split(',')

                    # Convert and create document according to schema
                    day = datetime.strptime(date_str, "%Y%m%d")  # Convert date string to datetime object

                    document = {
                        "symbol": symbol,
                        "day": day,
                        "o": float(o),      # Open
                        "h": float(h),      # High
                        "l": float(l),      # Low
                        "c": float(c),      # Close
                        "amount": float(amount),  # Amount
                        "v": int(v),        # Volume
                        "unknown": int(unknown)   # Unknown field
                    }

                    collection.insert_one(document)

                except ValueError as ve:
                    print(f"Warning: Line {line_num}: Could not convert data. Skipping. Error: {ve}")
                except Exception as e:
                    print(f"Warning: Line {line_num}: An error occurred. Skipping. Error: {e}")

        print(f"Data from '{input_file}' loaded into '{database_name}.{collection_name}'.")

    except pymongo.errors.ConnectionFailure as e:
        print(f"Error connecting to MongoDB: {e}")
    except Exception as e:
        print(f"A general error occurred: {e}")
    finally:
        if client:
            client.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Load stock data into MongoDB.")
    parser.add_argument("mongo_uri", help="MongoDB connection URI")
    parser.add_argument("database_name", help="Database name")
    parser.add_argument("collection_name", help="Collection name")
    parser.add_argument("input_file", help="Input file path")

    args = parser.parse_args()

    load_stock_data(args.mongo_uri, args.database_name, args.collection_name, args.input_file)
