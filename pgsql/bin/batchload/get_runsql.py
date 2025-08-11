import csv
from datetime import datetime

# Open the input CSV file and output SQL file
with open('chunks.csv', 'r') as csv_file, open('run_insert.sql', 'w') as sql_file:
    csv_reader = csv.reader(csv_file, delimiter='|')

    # Process each row
    for row in csv_reader:
        # Skip empty rows or rows with insufficient columns
        if len(row) < 3:
            continue

        # Extract and clean starttime and stoptime
        startid = row[1].strip()
        endid = row[2].strip()

        # Write to SQL file in the required format
        sql_file.write(f"\\set startid {startid}\n")
        sql_file.write(f"\\set endid {endid}\n")
        sql_file.write("\\i insert_prod.sql\n\n")
