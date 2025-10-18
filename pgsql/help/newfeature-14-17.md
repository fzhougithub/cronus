Upgrading from PostgreSQL 14 to 17 involves three major releases (15, 16, and 17), each introducing significant changes.

To quickly get the change and comparison, focus on the major themes: **Performance, SQL/Developer Features, and Replication.**

Here is a summary of the most impactful new features comparing PostgreSQL 17 to PostgreSQL 14, highlighting the cumulative changes across versions 15, 16, and 17.

***

## Quick Comparison: PostgreSQL 17 vs. 14

| Feature Category | PostgreSQL 14 State | Major Changes in PG 15, 16, & 17 (Cumulative) | PG 17 Highlight |
| :--- | :--- | :--- | :--- |
| **SQL Commands** | No `MERGE` | **PG 15:** Introduced the SQL standard `MERGE` command. | **PG 17:** Added `RETURNING` clause and `MERGE_ACTION()` to `MERGE` for better debugging and insight. |
| **JSON Support** | Basic `JSONB` functions | **PG 16:** Added more SQL/JSON features (`JSON_ARRAYAGG`, `JSON_OBJECTAGG`, etc.). | **PG 17:** Introduced the SQL-standard **`JSON_TABLE`** function to convert JSON to a relational table format, and more SQL/JSON constructors/query functions. |
| **Performance (Sorting)** | Good | **PG 15:** **Massive speedup** (up to 4x) for in-memory and on-disk sorting, especially for large data sets. | **PG 17:** Continual query planner improvements (e.g., better handling of `IN` clauses with B-tree indexes, improved materialized CTEs). |
| **Backup/WAL** | Basic `pg_basebackup` | **PG 15:** Added Zstandard (`zstd`) and LZ4 compression for WAL and server-side `pg_basebackup`. | **PG 17:** Added support for **Incremental Backups** with `pg_basebackup` and the new `pg_combinebackup` utility. |
| **Logical Replication** | Basic Replication | **PG 15:** Added **Row and Column filtering** (selective replication) and support for Two-Phase Commit (2PC). | **PG 17:** Introduced the **`pg_createsubscriber`** tool to simplify creating a logical replica from a physical standby, and failover control. |
| **Security/Admin** | `CREATE` granted on `public` to `PUBLIC` by default | **PG 15:** **Revoked default `CREATE` permission** on the `public` schema from the `PUBLIC` role (major security change). | **PG 17:** Added new predefined role **`pg_maintain`** for maintenance operations, and new monitoring views (`pg_wait_events`). |
| **Partitioning** | Basic Management | **PG 16:** Allowed parallel loading of data into partitioned tables. | **PG 17:** Added **`MERGE PARTITIONS`** and **`SPLIT PARTITIONS`** commands for on-the-fly table management, plus support for identity columns and exclusion constraints. |

***

## Key Features to Note When Upgrading from PG 14 to PG 17

### 1. **SQL & Developer Experience**
* **`MERGE` Command (PG 15):** This is the biggest new SQL feature, greatly simplifying complex conditional inserts/updates/deletes.
* **`JSON_TABLE` (PG 17):** A powerful tool for relationalizing and querying complex JSON data.
* **`SECURITY INVOKER` Views (PG 15):** A critical security feature for views that need to execute with the privileges of the user running the query, not the view's creator.

### 2. **Performance Gains**
* **Faster Sorting (PG 15):** You will see faster query execution for operations involving sorting (e.g., `ORDER BY`, index builds, complex window functions).
* **Parallelization (PG 15 & 16):** `SELECT DISTINCT` (PG 15) and several aggregate functions like `string_agg()` and `array_agg()` (PG 16) can now use parallel processing.
* **Vacuum Improvements (PG 17):** New internal memory structures reduce vacuum memory consumption by up to 20x.

### 3. **Security and Administration**
* **`public` Schema Security Change (PG 15):** If you are upgrading your instance, be aware that fresh PG 15+ installs default to a stricter permission model on the `public` schema. If you use `pg_upgrade`, existing permissions remain, but this is a *major* change in behavior for new setups.
* **JSON Logging (PG 15):** Better integration with modern log analysis tools via structured JSON logs.

### 4. **Backup and Replication**
* **Incremental Backups (PG 17):** The ability to create differential backups using `pg_basebackup` saves a huge amount of time and storage.
* **Logical Replication Filtering (PG 15):** Crucial for modern replication setups where you only need a subset of data or specific columns on the subscriber.
