#!/usr/bin/env python3
import psycopg2
import psycopg2.extras
import sys
import os
from pathlib import Path


KEY_SCHEMA = os.getenv("KEY_SCHEMA", "datamart_humana")

if not KEY_SCHEMA:
    raise ValueError("KEY_SCHEMA cannot be empty")


DSN = (
    "host=odshumana-pg16-04-alma9-prod-drx-kc.ssnc-corp.cloud "
    "port=5432 "
    "dbname=ods_domani "
    "user=fzhou"
)


def get_primary_key_columns(conn, table_fqn: str):
    """
    Returns primary key columns (name + type) from the base table.
    """
    sql = """
    SELECT
        a.attname,
        pg_catalog.format_type(a.atttypid, a.atttypmod)
    FROM pg_index i
    JOIN pg_attribute a
      ON a.attrelid = i.indrelid
     AND a.attnum = ANY(i.indkey)
    WHERE i.indrelid = %s::regclass
      AND i.indisprimary
    ORDER BY array_position(i.indkey, a.attnum);
    """

    with conn.cursor() as cur:
        cur.execute(sql, (table_fqn,))
        rows = cur.fetchall()

    if not rows:
        raise RuntimeError(f"No PRIMARY KEY found on {table_fqn}")

    return rows


def get_partition_tree(conn, root_table_fqn):
    """
    Same logic as your working script: full partition hierarchy.
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


def key_table_name(base_relname: str):
    return f"key_{base_relname}"


def generate_key_parent_table(schema, base_relname, pk_columns, part_key):
    cols = []
    pk_col_names = []

    for name, dtype in pk_columns:
        cols.append(f"    {name} {dtype} NOT NULL")
        pk_col_names.append(name)

    ddl = (
        f"CREATE TABLE {KEY_SCHEMA}.{key_table_name(base_relname)} (\n"
        #f"CREATE TABLE datamart_humana.{key_table_name(base_relname)} (\n"
        #f"CREATE TABLE {schema}.{key_table_name(base_relname)} (\n"
        + ",\n".join(cols)
        + f",\n    PRIMARY KEY ({', '.join(pk_col_names)})\n"
        + ")"
    )

    if part_key:
        ddl += f"\nPARTITION BY {part_key}"

    return ddl + ";\n"


def generate_key_partition(row, parent_relname):
    if not row["bound"]:
        return ""

    key_parent = f"{KEY_SCHEMA}.key_{parent_relname}"

    stmt = (
        f"CREATE TABLE {KEY_SCHEMA}.key_{row['relname']}\n"
        f"PARTITION OF {key_parent}\n"
        f"{row['bound']}"
    )

    #  CRITICAL FIX — preserve partition hierarchy
    if row["part_key"]:
        stmt += f"\nPARTITION BY {row['part_key']}"

    return stmt + ";\n"


def main(base_table_fqn):
    conn = psycopg2.connect(DSN)

    schema, base_relname = base_table_fqn.split(".", 1)
    key_root_fqn = f"{KEY_SCHEMA}.{key_table_name(base_relname)}"
    output_file = f"{KEY_SCHEMA}.{key_table_name(base_relname)}-creation.sql"

    pk_columns = get_primary_key_columns(conn, base_table_fqn)
    rows = get_partition_tree(conn, base_table_fqn)

    children = {}
    for r in rows:
        children.setdefault(r["parent_oid"], []).append(r)

    root = next(r for r in rows if r["parent_oid"] is None)

    output = []
    output.append(
        generate_key_parent_table(
            schema,
            base_relname,
            pk_columns,
            root["part_key"]
        )
    )
    
    def walk(parent_oid, parent_relname):
        for child in children.get(parent_oid, []):
            stmt = generate_key_partition(child, parent_relname)
            if stmt:
                output.append(stmt)
    
            walk(child["oid"], child["relname"])
    
    walk(root["oid"], root["relname"])

    conn.close()
    Path(output_file).write_text("\n".join(output))
    print(f"DDL written to {output_file}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 get_key_creation_code.py <schema.table>")
        sys.exit(1)

    main(sys.argv[1])
