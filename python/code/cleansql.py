# clean_sql.py
with open("ck_row_chunk.sql", "r", encoding="utf-8") as f:
    content = f.read()

# Remove problematic characters
cleaned = ''.join(
    c if (c.isascii() and c.isprintable()) or c in '\n\t\r ' else ' '
    for c in content
)

# Optionally, strip excessive spacing
cleaned = '\n'.join(line.rstrip() for line in cleaned.splitlines())

with open("clean_query.sql", "w", encoding="utf-8") as f:
    f.write(cleaned)

