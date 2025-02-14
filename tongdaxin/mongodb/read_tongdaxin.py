import argparse
from struct import unpack

def process_data(input_file, output_file):
    """Processes binary data from input_file and writes formatted data to output_file."""

    try:
        with open(input_file, 'rb') as ofile:
            buf = ofile.read()
    except FileNotFoundError:
        print(f"Error: Input file '{input_file}' not found.")
        return

    try:
        with open(output_file, 'w') as ifile:
            num = len(buf)
            no = num // 32
            b = 0
            e = 32

            for i in range(no):
                try:
                    a = unpack('IIIIIfII', buf[b:e])
                    line = f"{a[0]} {a[1] / 100.0} {a[2] / 100.0} {a[3] / 100.0} {a[4] / 100.0} {a[5] / 10.0} {a[6]} {a[7]}\n"
                    ifile.write(line)
                    b += 32
                    e += 32
                except struct.error:
                    print(f"Warning: Could not unpack data at offset {b}. Skipping.")
                    break # or continue if you want to keep going.

    except Exception as e: # Catch any other potential errors during file writing
        print(f"An error occurred during output file writing: {e}")
        return

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process binary stock data.")
    parser.add_argument("input_file", help="Path to the input binary file.")
    parser.add_argument("output_file", help="Path to the output text file.")

    args = parser.parse_args()

    process_data(args.input_file, args.output_file)
    print(f"Data processed. Output written to {args.output_file}")
