#!/usr/bin/env python3
import psycopg2
import psycopg2.extras
import sys
from pathlib import Path


DSN = (
    "host=odshumana-pg16-04-alma9-prod-drx-kc.ssnc-corp.cloud "
    "port=5432 "
    "dbname=ods_domani "
    "user=fzhou"
)


def get_primary_key_columns(conn, table_fqn):
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
        raise RuntimeError(f"No primary key on {table_fqn}")

    return rows


def get_partition_tree(conn, root_table_fqn):
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


def key_name(relname):
    return f"key_{relname}"


def create_key_parent(schema, base_relname, pk_cols, part_key):
    cols = []
    pk_names = []

    for name, dtype in pk_cols:
        cols.append(f"    {name} {dtype} NOT NULL")
        pk_names.append(name)

    ddl = (
        f"CREATE UNLOGGED TABLE {schema}.{key_name(base_relname)} (\n"
        + ",\n".join(cols)
        + f",\n    PRIMARY KEY ({', '.join(pk_names)})\n"
        + ")"
    )

    if part_key:
        ddl += f"\nPARTITION BY {part_key}"

    return ddl + ";\n"


def create_key_partition(row, parent_fqn):
    if not row["bound"]:
        return ""
    return (
        f"CREATE TABLE {row['nspname']}.key_{row['relname']}\n"
        f"PARTITION OF {parent_fqn}\n"
        f"{row['bound']};\n"
    )


def insert_sql(schema, base_relname, pk_cols):
    col_list = ", ".join(c[0] for c in pk_cols)
    return (
        f"-- Populate key table\n"
        f"INSERT INTO {schema}.{key_name(base_relname)} ({col_list})\n"
        f"SELECT {col_list}\n"
        f"FROM {schema}.{base_relname};\n"
    )


def main(base_table_fqn):
    conn = psycopg2.connect(DSN)

    schema, base_relname = base_table_fqn.split(".", 1)
    output_file = f"{schema}.{key_name(base_relname)}-creation.sql"

    pk_cols = get_primary_key_columns(conn, base_table_fqn)
    rows = get_partition_tree(conn, base_table_fqn)

    children = {}
    for r in rows:
        children.setdefault(r["parent_oid"], []).append(r)

    root = next(r for r in rows if r["parent_oid"] is None)

    out = []
    out.append(create_key_parent(schema, base_relname, pk_cols, root["part_key"]))

    def walk(parent_oid, parent_fqn):
        for child in children.get(parent_oid, []):
            stmt = create_key_partition(child, parent_fqn)
            if stmt:
                out.append(stmt)
            walk(child["oid"], f"{child['nspname']}.key_{child['relname']}")

    walk(root["oid"], f"{schema}.{key_name(base_relname)}")

    out.append(insert_sql(schema, base_relname, pk_cols))

    conn.close()
    Path(output_file).write_text("\n".join(out))
    print(f"DDL written to {output_file}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 get_key_creation_code.py <schema.table>")
        sys.exit(1)
    main(sys.argv[1])
