#!/usr/bin/env python3

import psycopg2
import psycopg2.extras
import sys
import os
import hashlib
from pathlib import Path


KEY_SCHEMA = os.getenv("KEY_SCHEMA", "datamart_humana")

if not KEY_SCHEMA.strip():
    raise ValueError("KEY_SCHEMA cannot be empty")


DSN = (
    "host=odshumana-pg16-04-alma9-prod-drx-kc.ssnc-corp.cloud "
    "port=5432 dbname=ods_domani user=fzhou"
)

# Your tablespaces (ordered list)
TABLESPACES = [f"tblspc_{i}" for i in range(1, 21)]


def choose_tablespace(base_ts, relname):
    """
    Pick a tablespace different from base_ts
    using hash distribution.
    """
    candidates = [ts for ts in TABLESPACES if ts != base_ts]

    h = int(hashlib.md5(relname.encode()).hexdigest(), 16)
    return candidates[h % len(candidates)]


def get_base_partition_tablespaces(conn, schema, base_relname):
    """
    Return mapping: relname -> tablespace
    """
    sql = """
    SELECT
        c.relname,
        COALESCE(ts.spcname, 'pg_default') AS tablespace
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    LEFT JOIN pg_tablespace ts ON ts.oid = c.reltablespace
    WHERE n.nspname = %s
      AND (
            c.relname = %s
         OR c.relname LIKE %s
      )
      AND c.relkind = 'r'
    """

    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        cur.execute(sql, (schema, base_relname, f"{base_relname}_%"))
        rows = cur.fetchall()

    result = {}
    for r in rows:
        result[r["relname"]] = r["tablespace"]

    return result


def main(base_table_fqn):
    conn = psycopg2.connect(DSN)

    base_schema, base_relname = base_table_fqn.split(".", 1)

    base_ts_map = get_base_partition_tablespaces(
        conn, base_schema, base_relname
    )

    output = []

    for relname, base_ts in base_ts_map.items():
        key_table = f"{KEY_SCHEMA}.key_{relname}"

        # choose different TS
        new_ts = choose_tablespace(base_ts, relname)

        output.append(
            f"ALTER TABLE {key_table} SET TABLESPACE {new_ts};"
        )

    conn.close()

    output_file = f"{KEY_SCHEMA}.key_{base_relname}-tablespace.sql"
    Path(output_file).write_text("\n".join(output))

    print(f"Tablespace script written to {output_file}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 get_key_alter_code.py <schema.table>")
        sys.exit(1)

    main(sys.argv[1])
