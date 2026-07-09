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

def key_name(relname):
    return f"key_{relname}"

def get_primary_key_columns(conn, table_fqn):
    sql = """
    SELECT
        a.attname
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
        raise RuntimeError(f"No PRIMARY KEY on {table_fqn}")

    return [r[0] for r in rows]

def main(base_table_fqn):
    conn = psycopg2.connect(DSN)
    schema, base_relname = base_table_fqn.split(".", 1)

    pk_cols = get_primary_key_columns(conn, base_table_fqn)
    pk_list = ", ".join(pk_cols)

    sql = """
    SELECT
        n.nspname,
        c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = %s
      AND c.relispartition = true
      AND c.relkind = 'r'
      AND NOT EXISTS (
          SELECT 1
          FROM pg_inherits i
          WHERE i.inhparent = c.oid
      )
      AND c.relname LIKE %s
    ORDER BY c.relname;
    """

    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        cur.execute(sql, (schema, f"{base_relname}_%"))
        leaves = cur.fetchall()

    inserts = []
    for leaf in leaves:
        base_leaf = f"{schema}.{leaf['relname']}"
        key_leaf = f"{schema}.{key_name(leaf['relname'])}"

        inserts.append(
            f"INSERT INTO {key_leaf} ({pk_list}) "
            f"SELECT {pk_list} "
            f"FROM {base_leaf};"
        )

    conn.close()

    output_file = f"{schema}.{key_name(base_relname)}-leaf-inserts.sql"
    Path(output_file).write_text("\n\n".join(inserts))

    print(f"Leaf-level insert script written to {output_file}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 get_key_insert_sql.py <schema.table>")
        sys.exit(1)

    main(sys.argv[1])
