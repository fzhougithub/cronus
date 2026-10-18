#!/usr/bin/env python3

import re
import argparse
import psycopg2


class PartitionQueryExecutor:

    def __init__(self, conn):

        self.conn = conn

        #
        # Logical table -> partition pattern
        #
        self.partition_map = {
            "a": "a_202%"
        }

    ####################################################################
    # Get partition tables
    ####################################################################

    def get_partition_tables(self, cur, logical_table):

        pattern = self.partition_map[logical_table]

        cur.execute(
            """
            SELECT tablename
            FROM pg_tables
            WHERE schemaname = 'public'
              AND tablename LIKE %s
            ORDER BY tablename
            """,
            (pattern,)
        )

        return [r[0] for r in cur.fetchall()]

    ####################################################################
    # Find logical tables in SQL
    ####################################################################

    def find_logical_tables(self, sql_text):

        found = []

        for table in self.partition_map.keys():

            from_pattern = rf'\bFROM\s+{table}\b'
            join_pattern = rf'\bJOIN\s+{table}\b'

            if re.search(from_pattern,
                         sql_text,
                         re.IGNORECASE):

                found.append(table)
                continue

            if re.search(join_pattern,
                         sql_text,
                         re.IGNORECASE):

                found.append(table)

        return found

    ####################################################################
    # Extract WHERE clause for pushdown
    ####################################################################

    def extract_where_clause(self, sql_text):

        m = re.search(
            r'\bWHERE\b(.*?)(GROUP\s+BY|ORDER\s+BY|HAVING|LIMIT|$)',
            sql_text,
            re.IGNORECASE | re.DOTALL
        )

        if not m:
            return ""

        return m.group(1).strip()

    ####################################################################
    # Build raw temp table
    ####################################################################

    def build_raw_union_sql(
            self,
            sql_text,
            logical_table,
            physical_tables):

        #
        # Convert:
        #
        # select customer_id,count(*)
        # from a
        # where customer_id=320
        # group by customer_id
        #
        # into:
        #
        # select *
        # from a_2021
        # where customer_id=320
        #
        # union all
        #
        # select *
        # from a_2022
        # where customer_id=320
        #

        where_clause = self.extract_where_clause(
            sql_text
        )

        parts = []

        for table in physical_tables:

            stmt = f"SELECT * FROM {table}"

            if where_clause:
                stmt += f" WHERE {where_clause}"

            parts.append(stmt)

        return "\nUNION ALL\n".join(parts)

    ####################################################################
    # Rewrite final SQL
    ####################################################################

    def rewrite_final_sql(
            self,
            sql_text,
            logical_table):

        sql_text = re.sub(
            rf'(\bFROM\s+){logical_table}(\b)',
            r'\1tmp_result_raw\2',
            sql_text,
            flags=re.IGNORECASE
        )

        sql_text = re.sub(
            rf'(\bJOIN\s+){logical_table}(\b)',
            r'\1tmp_result_raw\2',
            sql_text,
            flags=re.IGNORECASE
        )

        return sql_text

    ####################################################################
    # Execute
    ####################################################################

    def execute(self, sql_text):

        with self.conn.cursor() as cur:

            logical_tables = self.find_logical_tables(
                sql_text
            )

            print("\nLogical Tables Found:")
            print(logical_tables)

            if len(logical_tables) == 0:

                cur.execute(sql_text)
                return cur.fetchall()

            if len(logical_tables) > 1:

                raise Exception(
                    "Current version supports "
                    "one logical partitioned table only."
                )

            logical_table = logical_tables[0]

            physical_tables = self.get_partition_tables(
                cur,
                logical_table
            )

            print("\nPhysical Tables:")
            print(physical_tables)

            #
            # Phase 1
            #
            raw_union_sql = self.build_raw_union_sql(
                sql_text,
                logical_table,
                physical_tables
            )

            print("\nRaw Union SQL:")
            print("=" * 80)
            print(raw_union_sql)
            print("=" * 80)

            cur.execute(
                "DROP TABLE IF EXISTS tmp_result_raw"
            )

            create_sql = f"""
            CREATE TEMP TABLE tmp_result_raw AS
            {raw_union_sql}
            """

            print("\nCreate Temp SQL:")
            print("=" * 80)
            print(create_sql)
            print("=" * 80)

            cur.execute(create_sql)

            #
            # Phase 2
            #
            final_sql = self.rewrite_final_sql(
                sql_text,
                logical_table
            )

            print("\nFinal SQL:")
            print("=" * 80)
            print(final_sql)
            print("=" * 80)

            cur.execute(final_sql)

            rows = cur.fetchall()

            return rows


def main():

    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--sql",
        required=True,
        help="SQL statement"
    )

    args = parser.parse_args()

    conn = psycopg2.connect(
        host="ods-pg16-01-alma9-dev-drx-kc.ssnc-corp.cloud",
        port=5432,
        database="ods_domani",
        user="fzhou"
    )

    try:

        executor = PartitionQueryExecutor(conn)

        rows = executor.execute(
            args.sql
        )

        print("\nResult Set:")
        print("=" * 80)

        for row in rows:
            print(row)

    finally:

        conn.close()


if __name__ == "__main__":
    main()
