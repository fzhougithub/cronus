# cleancode.py
import sys
import os

def clean_file(input_filename):
    # Generate output filename
    base, ext = os.path.splitext(input_filename)
    output_filename = f"{input_filename}_clean"
    
    with open(input_filename, "r", encoding="utf-8") as f:
        content = f.read()

    # Remove problematic characters
    cleaned = ''.join(
        c if (c.isascii() and c.isprintable()) or c in '\n\t\r ' else ' '
        for c in content
    )

    # Optionally, strip excessive spacing
    cleaned = '\n'.join(line.rstrip() for line in cleaned.splitlines())

    with open(output_filename, "w", encoding="utf-8") as f:
        f.write(cleaned)
    print(f"Cleaned file saved as: {output_filename}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python cleancode.py <input_file>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    if not os.path.exists(input_file):
        print(f"Error: File '{input_file}' not found")
        sys.exit(1)
        
    clean_file(input_file)
