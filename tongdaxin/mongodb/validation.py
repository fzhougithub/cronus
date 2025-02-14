import csv

with open("a", "r") as file:
    reader = csv.DictReader(file)
    for row in reader:
        try:
            amount = float(row["amount"])  # Replace "amount" with the actual field name
            print(f"Amount: {amount}")
        except ValueError as e:
            print(f"Error converting amount: {row['amount']}. Error: {e}")
