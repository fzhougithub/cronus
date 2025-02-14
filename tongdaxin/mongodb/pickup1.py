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
        target_date = datetime.strptime(target_date_str, '%Y%m%d')
    except ValueError:
        print("Incorrect date format. Please use YYYYMMDD.")
        sys.exit(1)

    filtered_rows = []

    try:
        with open(csv_file_path, mode='r', newline='', encoding='utf-8') as csvfile:
            reader = csv.reader(csvfile, delimiter=delimiter)
            next(reader)  # Skip the header
            for row_num, row in enumerate(reader, start=2):
                if date_column_index >= len(row):
                    print(f"Row {row_num}: Insufficient columns. Expected at least {date_column_index + 1}, got {len(row)}.")
                    continue
                row_date_str = row[date_column_index]
                try:
                    row_date = datetime.strptime(row_date_str, '%Y%m%d')
                except ValueError:
                    print(f"Row {row_num}: Invalid date format '{row_date_str}'. Expected YYYYMMDD.")
                    continue
                
                if row_date > target_date:
                    filtered_rows.append(row)
    except FileNotFoundError:
        print(f"Error: The file '{csv_file_path}' does not exist.")
        sys.exit(1)
    except Exception as e:
        print(f"An error occurred while reading the file: {e}")
        sys.exit(1)

    return filtered_rows

def main():
    if len(sys.argv) != 3:
        print("Usage: python pickup.py <csv_file_path> <target_date>")
        print("Example: python pickup.py /var/tmp/sz399974.day 20250101")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    target_date = sys.argv[2]

    filtered_data = filter_csv_by_date(csv_file, target_date)

    if filtered_data:
        # Define which columns to include (exclude 'Split' which is index 8)
        selected_columns_indices = [0, 1, 2, 3, 4, 5, 6, 7]  # Adjust as needed
        # Print only the selected columns for each row
        for row in filtered_data:
            selected_row = [row[i] for i in selected_columns_indices]
            print(",".join(map(str, selected_row)))
    else:
        print("No data found after the specified date.")

if __name__ == "__main__":
    main()
