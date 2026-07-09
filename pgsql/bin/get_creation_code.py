#!/usr/bin/env python3
import psycopg2
import psycopg2.extras
from pathlib import Path

DSN = (
    "host=ods-db-05-alma8-prod-drx-kc.ssnc-corp.cloud "
    "port=5432 "
    "dbname=ods_domani "
    "user=fzhou"
)


def make_output_filename(table_fqn: str) -> str:
    return f"{table_fqn}-creation.sql"


def get_table_columns(conn, table_fqn: str) -> str:
    sql = """
    SELECT
        a.attname,
        pg_catalog.format_type(a.atttypid, a.atttypmod),
        a.attnotnull,
        pg_get_expr(ad.adbin, ad.adrelid),
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


def get_primary_key(conn, table_fqn: str) -> str:
    sql = """
    SELECT string_agg(a.attname, ', ' ORDER BY a.attnum)
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    JOIN unnest(c.conkey) WITH ORDINALITY AS cols(attnum, ord) ON TRUE
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = cols.attnum
    WHERE c.contype = 'p'
      AND n.nspname || '.' || t.relname = %s;
    """

    with conn.cursor() as cur:
        cur.execute(sql, (table_fqn,))
        row = cur.fetchone()

    if row and row[0]:
        return f"PRIMARY KEY ({row[0]})"
    return ""


def get_partition_tree(conn, table_fqn: str):
    sql = """
    WITH RECURSIVE part_tree AS (
        SELECT
            c.oid,
            c.relname,
            n.nspname,
            NULL::oid AS parent_oid,
            CASE WHEN c.relkind = 'p'
                 THEN pg_get_partkeydef(c.oid) COLLATE "C"
                 ELSE NULL END AS part_key,
            NULL::text COLLATE "C" AS bound
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname || '.' || c.relname = %s

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
        cur.execute(sql, (table_fqn,))
        return cur.fetchall()

def generate_create_parent(conn, row) -> str:
    table_fqn = f"{row['nspname']}.{row['relname']}"
    columns = get_table_columns(conn, table_fqn)
    pk = get_primary_key(conn, table_fqn)

    if pk:
        columns += ",\n    " + pk

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


def main(table_fqn: str):
    output_file = make_output_filename(table_fqn)

    conn = psycopg2.connect(DSN)

    rows = get_partition_tree(conn, table_fqn)
    if not rows:
        conn.close()
        raise RuntimeError(f"No such table: {table_fqn}")

    root = rows[0]

    # ✅ Non-partitioned table
    if root["part_key"] is None:
        output = [generate_create_parent(conn, root)]

    else:
        children = {}
        for r in rows:
            children.setdefault(r["parent_oid"], []).append(r)

        output = [generate_create_parent(conn, root)]

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

    main(sys.argv[1])
