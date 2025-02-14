import csv
from datetime import datetime
import sys

def filter_csv_by_date(csv_file_path, target_date_str, date_column_index=1, delimiter=','):
    """
    Filters rows in a CSV file where the date in the specified column is later than the target date.

    :param csv_file_path: Path to the CSV file.
    :param target_date_str: Target date as a string (format: YYYYMMDD).
    :param date_column_index: Index of the date column (0-based).
    :param delimiter: Delimiter used in the CSV file.
    :return: List of filtered rows.
    """
    try:
        # Parse the target date
        target_date = datetime.strptime(target_date_str, '%Y%m%d')
    except ValueError:
        print("Incorrect date format. Please use YYYYMMDD.")
        sys.exit(1)

    filtered_rows = []

    with open(csv_file_path, mode='r', newline='', encoding='utf-8') as csvfile:
        reader = csv.reader(csvfile, delimiter=delimiter)
        
        # Assuming the first row is header; adjust if not
        headers = next(reader)
        
        for row_num, row in enumerate(reader, start=2):  # Start counting from line 2
            try:
                row_date_str = row[date_column_index]
                row_date = datetime.strptime(row_date_str, '%Y%m%d')
                
                if row_date > target_date:
                    filtered_rows.append(row)
            except ValueError:
                print(f"Skipping row {row_num}: Invalid date format '{row_date_str}'. Expected YYYYMMDD.")
                continue

    return filtered_rows

def main():
    if len(sys.argv) != 3:
        print("Usage: python filter_csv.py <csv_file_path> <target_date>")
        print("Example: python filter_csv.py data.csv 20250206")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    target_date = sys.argv[2]

    filtered_data = filter_csv_by_date(csv_file, target_date)

    if filtered_data:
        # Print headers
        print(",".join(["Column1", "Date", "Open", "High", "Low", "Close", "Volume", "Dividend", "Split"]))
        # Print filtered rows
        for row in filtered_data:
            print(",".join(map(str, row)))
    else:
        print("No data found after the specified date.")

if __name__ == "__main__":
    main()
