#!/Users/fzhou/work/p3/bin/python

import re
import sys

def extract_altered_tables(sql_file):
    alter_table_pattern = re.compile(
        r'ALTER\s+TABLE\s+(IF\s+EXISTS\s+)?((?:"?[\w]+"?\.)?"?[\w]+"?)',
        re.IGNORECASE
    )
    tables = set()
    with open(sql_file, 'r') as f:
        content = f.read()
    matches = alter_table_pattern.findall(content)
    for match in matches:
        full_table = match[1].replace('"', '')
        tables.add(full_table)
    return sorted(tables)

def extract_created_tables(sql_file):
    create_table_pattern = re.compile(
        r'CREATE\s+TABLE\s+(IF\s+NOT\s+EXISTS\s+)?((?:"?[\w]+"?\.)?"?[\w]+"?)',
        re.IGNORECASE
    )
    tables = set()
    with open(sql_file, 'r') as f:
        content = f.read()
    matches = create_table_pattern.findall(content)
    for match in matches:
        full_table = match[1].replace('"', '')
        tables.add(full_table)
    return sorted(tables)

def detect_dml_statements(sql_file):
    dml_pattern = re.compile(r'^\s*(INSERT|UPDATE|DELETE)\b', re.IGNORECASE)
    inside_func = False
    dml_lines = []
    with open(sql_file, 'r') as f:
        for line in f:
            line_strip = line.strip()
            if re.match(r'^\s*CREATE\s+(OR\s+REPLACE\s+)?FUNCTION\b', line_strip, re.IGNORECASE) or re.match(r'^\s*DO\b', line_strip, re.IGNORECASE):
                inside_func = True
            if inside_func and re.search(r'\$\$|\bEND\s*;\s*$', line_strip, re.IGNORECASE):
                inside_func = False
                continue
            if not inside_func and dml_pattern.search(line):
                dml_lines.append(line_strip)
    return dml_lines

def format_table_list(tables):
    return ",\n  ".join(tables)

def write_tablist_file(tables):
    if not tables:
        return
    with open("tablist", "w") as f:
        for table in tables:
            f.write(f"{table}\n")

def generate_replication_control_sql(publication, subscription, altered_tables, created_tables, dml_lines):
    blocks = []

    if dml_lines:
        warning = (
            "WARNING: DML (INSERT/UPDATE/DELETE) detected in the same script:\n"
            + "\n".join(f"  → {line}" for line in dml_lines) +
            "\n\nDo NOT run DML while tables are removed from replication.\n"
            "Consider splitting the file or applying DDL & DML separately.\n"
        )
        blocks.append(warning)

    # Step 1: DROP altered tables from publication
    if altered_tables:
        blocks.append(
            f"ALTER PUBLICATION {publication}\nDROP TABLE\n  {format_table_list(altered_tables)};"
        )
        blocks.append(f"ALTER SUBSCRIPTION {subscription} REFRESH PUBLICATION;")
        blocks.append("-- Apply schema changes on both publisher and subscriber manually here.")

    # Step 2: ADD combined altered + created tables back
    combined_tables = sorted(set(created_tables + altered_tables))
    if combined_tables:
        blocks.append(
            f"ALTER PUBLICATION {publication}\nADD TABLE\n  {format_table_list(combined_tables)};"
        )
        if created_tables:
            blocks.append(f"ALTER SUBSCRIPTION {subscription} REFRESH PUBLICATION with (copy_data = true);")
        else:
            blocks.append(f"-- Carefully consider whether TRUNCATE sub table before refresh;")
            blocks.append(f"ALTER SUBSCRIPTION {subscription} REFRESH PUBLICATION;")

    if not altered_tables and not created_tables:
        blocks.append("-- No ALTER TABLE or CREATE TABLE statements detected.")

    return "\n\n".join(blocks)

def main():
    if len(sys.argv) != 4:
        print("Usage: python review_ddl.py <pub_name> <sub_name> <sql_file>")
        sys.exit(1)

    publication = sys.argv[1]
    subscription = sys.argv[2]
    sql_file = sys.argv[3]

    altered_tables = extract_altered_tables(sql_file)
    created_tables = extract_created_tables(sql_file)
    dml_lines = detect_dml_statements(sql_file)

    # Combine both ALTERed and CREATEd tables for tablist
    all_tables = sorted(set(altered_tables + created_tables))
    write_tablist_file(all_tables)

    # Output replication SQL to console
    output = generate_replication_control_sql(publication, subscription, altered_tables, created_tables, dml_lines)
    print(output)

if __name__ == "__main__":
    main()

