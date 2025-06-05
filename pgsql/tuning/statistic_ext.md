To check the collected extended statistics in PostgreSQL, you can query the pg_statistic_ext system catalog table. This table stores the extended statistics that have been collected for tables and columns in the database.

Here’s how you can query the pg_statistic_ext table to view the collected extended statistics:
List All Extended Statistics

To see all the extended statistics defined in the database, you can query the pg_statistic_ext table:
SELECT * FROM pg_statistic_ext;

This will return a list of all extended statistics objects, including their names, the tables they belong to, and the types of statistics they represent (e.g., dependencies, ndistinct, etc.).
View Details of a Specific Extended Statistic

To view the details of a specific extended statistic, you can join the pg_statistic_ext table with other system catalogs like pg_class and pg_namespace to get more information about the table and schema:
SELECT
    s.stxname AS statistic_name,
    n.nspname AS schema_name,
    c.relname AS table_name,
    s.stxkind AS statistic_kind
FROM
    pg_statistic_ext s
JOIN
    pg_class c ON s.stxrelid = c.oid
JOIN
    pg_namespace n ON c.relnamespace = n.oid;

This query will return the name of the extended statistic, the schema and table it belongs to, and the type of statistic (e.g., d for dependencies, n for n-distinct).
View the Actual Collected Values

The actual collected values for extended statistics are stored in the pg_statistic_ext_data system catalog table. However, this table is not directly queryable by users because the data is stored in a binary format. Instead, you can use the pg_stats_ext view, which provides a more user-friendly representation of the extended statistics.

To view the collected values for extended statistics, you can query the pg_stats_ext view:
SELECT * FROM pg_stats_ext WHERE stxname = 'your_statistic_name';

Replace 'your_statistic_name' with the name of the extended statistic you want to inspect.

Example: Viewing Dependencies Statistics

If you have created an extended statistic for dependencies (e.g., CREATE STATISTICS deps (dependencies) ON col1, col2 FROM my_table), you can query the pg_stats_ext view to see the collected dependency information:
SELECT * FROM pg_stats_ext WHERE stxname = 'deps';

This will show you the dependencies between col1 and col2 based on the collected data.

Notes:
Extended statistics are not automatically collected by ANALYZE. You must explicitly create them using the CREATE STATISTICS command.

The pg_stats_ext view provides a more user-friendly way to inspect the collected values for extended statistics compared to directly querying pg_statistic_ext_data.

If you need more detailed information about the binary format used in pg_statistic_ext_data, you would need to refer to the PostgreSQL source code or documentation, as it is not intended for direct user consumption.
