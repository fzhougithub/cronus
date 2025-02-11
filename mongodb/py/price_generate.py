import pymongo
import time
import random
from datetime import datetime, timedelta

# MongoDB connection details
MONGO_URI = "mongodb://fzhou:jgmjxdd@192.168.1.75:27017"  # Replace with your MongoDB URI
DATABASE_NAME = "fzhou"
COLLECTION_NAME = "pricehistory"

# Stock symbols to simulate
STOCK_SYMBOLS = ["AAPL", "MSFT", "GOOG", "AMZN", "TSLA"]  # Add more symbols

def generate_random_price(current_price):
    """Generates a random price change."""
    change_percentage = random.uniform(-0.02, 0.02)  # Price can change by +/- 2%
    price_change = current_price * change_percentage
    new_price = current_price + price_change
    return round(new_price, 2)

def generate_random_volume():
    """Generates a random volume (number of shares traded)."""
    return random.randint(100000, 10000000)  # Volume between 100,000 and 10,000,000

def simulate_stock_prices(db):
    """Simulates stock price and volume generation and writes to MongoDB."""
    current_prices = {}  # Store current prices for each stock

    # Initialize starting prices
    for symbol in STOCK_SYMBOLS:
        current_prices[symbol] = random.uniform(50, 200)

    while True:
        timestamp = datetime.now().replace(microsecond=0) # Minute-level timestamp
        #timestamp = datetime.now().replace(second=0, microsecond=0) # Minute-level timestamp

        for symbol in STOCK_SYMBOLS:
            new_price = generate_random_price(current_prices[symbol])
            current_prices[symbol] = new_price
            volume = generate_random_volume()

            price_data = {
                "symbol": symbol,
                "price": new_price,
                "volume": volume,
                "timestamp": timestamp,
            }

            try:
                db[COLLECTION_NAME].insert_one(price_data)
                print(f"{timestamp}: {symbol} - ${new_price} - Volume: {volume}")
            except pymongo.errors.ConnectionFailure as e:
                print(f"MongoDB Connection Error: {e}")
                return
            except Exception as e:
                print(f"Error inserting data: {e}")

        time.sleep(5)  # Wait for 1 minute


if __name__ == "__main__":
    try:
        client = pymongo.MongoClient(MONGO_URI)
        db = client[DATABASE_NAME]
        simulate_stock_prices(db)
    except pymongo.errors.ConnectionFailure as e:
        print(f"MongoDB Connection Error: {e}")
    except Exception as e:
        print(f"An error occurred: {e}")
    finally:
        if client:
            client.close()
