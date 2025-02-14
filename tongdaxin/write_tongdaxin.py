import argparse
import pymongo
import os
from datetime import datetime

def load_stock_data(mongo_uri, database_name, collection_name, input_file):
    """Loads stock data into a MongoDB collection, adding 'symbol' and converting to schema."""

    try:
        client = pymongo.MongoClient(mongo_uri)
        db = client[database_name]
        collection = db[collection_name]

        base_name = os.path.basename(input_file)
        try:
            symbol = base_name[2:-4]
            if not symbol:
                raise ValueError("Symbol is empty")
        except (IndexError, ValueError):
            print(f"Warning: Invalid filename format: {base_name}. Skipping file.")
            return

        with open(input_file, 'r') as file:
            for line in file:
                try:
                    date_str, o, h, l, c, amount, v, unknown = line.strip().split()  # Use correct variable names

                    # Convert and create document according to schema
                    try:
                        day = datetime.strptime(str(date_str), "%Y%m%d") # Convert date string to datetime object
                    except ValueError:
                        print(f"Warning: Invalid date format: {date_str}. Skipping line")
                        continue

                    document = {
                        "symbol": symbol,
                        "day": day,
                        "o": float(o),  # Use correct field names from schema
                        "h": float(h),
                        "l": float(l),
                        "c": float(c),
                        "amount": float(amount),
                        "v": int(v)
                    }

                    collection.insert_one(document)

                except ValueError:
                    print(f"Warning: Could not convert data in line: {line.strip()}. Skipping.")
                except Exception as e:
                    print(f"An error occurred inserting data: {e}. Skipping line.")

        print(f"Data from '{input_file}' loaded into '{database_name}.{collection_name}' with symbol '{symbol}'")

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
