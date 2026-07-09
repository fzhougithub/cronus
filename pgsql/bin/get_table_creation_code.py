#!/usr/bin/env python3
import psycopg2
import psycopg2.extras
from pathlib import Path

# Uses ~/.pgpass (no password here)
DSN = (
    "host=odshumana-pg16-04-alma9-prod-drx-kc.ssnc-corp.cloud "
    "port=5432 "
    "dbname=ods_domani "
    "user=fzhou"
)

OUTPUT_FILE = "generated_partitions.sql"


def get_table_columns(conn, table_fqn: str) -> str:
    """
    Returns executable column definitions for the given table.
    ONLY used for the root parent table.
    """
    sql = """
    SELECT
        a.attname,
        pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
        a.attnotnull,
        pg_get_expr(ad.adbin, ad.adrelid) AS default_expr,
        a.attgenerated
    FROM pg_attribute a
    LEFT JOIN pg_attrdef ad
           ON ad.adrelid = a.attrelid
          AND ad.adnum = a.attnum
    WHERE a.attrelid = %s::regclass
      AND a.attnum > 0
      AND NOT a.attisdropped
    ORDER BY a.attnum;
    """

    with conn.cursor() as cur:
        cur.execute(sql, (table_fqn,))
        rows = cur.fetchall()

    col_lines = []
    for name, dtype, notnull, default, generated in rows:
        line = f"    {name} {dtype}"

        if generated:
            line += f" GENERATED {generated} AS IDENTITY"
        elif default:
            line += f" DEFAULT {default}"

        if notnull:
            line += " NOT NULL"

        col_lines.append(line)

    return ",\n".join(col_lines)


def get_partition_tree(conn, root_table_fqn: str):
    """
    Discovers full partition hierarchy using system catalogs.
    """
    sql = """
    WITH RECURSIVE part_tree AS (
        SELECT
            c.oid,
            c.relname,
            n.nspname,
            NULL::oid AS parent_oid,
            pg_get_partkeydef(c.oid) COLLATE "C" AS part_key,
            NULL::text COLLATE "C" AS bound
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relkind = 'p'
          AND n.nspname || '.' || c.relname = %s

        UNION ALL

        SELECT
            c.oid,
            c.relname,
            n.nspname,
            i.inhparent,
            pg_get_partkeydef(c.oid) COLLATE "C",
            pg_get_expr(c.relpartbound, c.oid) COLLATE "C"
        FROM pg_inherits i
        JOIN pg_class c ON c.oid = i.inhrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN part_tree p ON p.oid = i.inhparent
    )
    SELECT *
    FROM part_tree
    ORDER BY parent_oid NULLS FIRST;
    """

    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        cur.execute(sql, (root_table_fqn,))
        return cur.fetchall()


def generate_create_parent(conn, row) -> str:
    """
    Generates CREATE TABLE statement for the root parent,
    including real column definitions.
    """
    table_fqn = f"{row['nspname']}.{row['relname']}"
    columns = get_table_columns(conn, table_fqn)

    part_clause = ""
    if row["part_key"]:
        part_clause = f"\nPARTITION BY {row['part_key']}"

    return (
        f"CREATE TABLE {table_fqn} (\n"
        f"{columns}\n"
        f")"
        f"{part_clause};\n"
    )


def generate_create_partition(row, parent_fqn: str) -> str:
    """
    Generates CREATE TABLE ... PARTITION OF ... statement
    for non-root partitions.
    """
    if not row["bound"]:
        return ""

    stmt = (
        f"CREATE TABLE {row['nspname']}.{row['relname']}\n"
        f"PARTITION OF {parent_fqn}\n"
        f"{row['bound']}"
    )

    if row["part_key"]:
        stmt += f"\nPARTITION BY {row['part_key']}"

    return stmt + ";\n"


def main(parent_table_fqn: str):
    conn = psycopg2.connect(DSN)

    rows = get_partition_tree(conn, parent_table_fqn)
    if not rows:
        raise RuntimeError(f"No such partitioned table: {parent_table_fqn}")

    children = {}
    for r in rows:
        children.setdefault(r["parent_oid"], []).append(r)

    root = next(r for r in rows if r["parent_oid"] is None)

    output = []
    output.append(generate_create_parent(conn, root))

    def walk(parent_oid, parent_fqn):
        for child in children.get(parent_oid, []):
            stmt = generate_create_partition(child, parent_fqn)
            if stmt:
                output.append(stmt)
            walk(child["oid"], f"{child['nspname']}.{child['relname']}")

    walk(root["oid"], f"{root['nspname']}.{root['relname']}")

    conn.close()

    Path(OUTPUT_FILE).write_text("\n".join(output))
    print(f"DDL written to {OUTPUT_FILE}")


def make_output_filename(table_fqn: str) -> str:
    """
    claimsprocess_humana.claim_error
    -> claimsprocess_humana.claim_error-creation.sql
    """
    return f"{table_fqn}-creation.sql"

def main(parent_table_fqn: str):
    output_file = make_output_filename(parent_table_fqn)

    conn = psycopg2.connect(DSN)

    rows = get_partition_tree(conn, parent_table_fqn)
    if not rows:
        conn.close()
        raise RuntimeError(f"No such partitioned table: {parent_table_fqn}")

    children = {}
    for r in rows:
        children.setdefault(r["parent_oid"], []).append(r)

    root = next(r for r in rows if r["parent_oid"] is None)

    output = []
    output.append(generate_create_parent(conn, root))

    def walk(parent_oid, parent_fqn):
        for child in children.get(parent_oid, []):
            stmt = generate_create_partition(child, parent_fqn)
            if stmt:
                output.append(stmt)
            walk(child["oid"], f"{child['nspname']}.{child['relname']}")

    walk(root["oid"], f"{root['nspname']}.{root['relname']}")

    conn.close()

    Path(output_file).write_text("\n".join(output))
    print(f"DDL written to {output_file}")


if __name__ == "__main__":
    import sys

    if len(sys.argv) != 2:
        print("Usage: python3 get_creation_code.py <schema.table>")
        sys.exit(1)

    parent_table_fqn = sys.argv[1]
    main(parent_table_fqn)
