Perfect 👍 let’s build a **step-by-step recipe** so you can query PostgreSQL logs just like you do in MySQL.
We’ll use PostgreSQL’s built-in **`csvlog`** format.

---

## 🔹 Step 1. Enable CSV logging in `postgresql.conf`

Edit your config and add/ensure:

```conf
logging_collector = on
log_destination = 'csvlog'
log_directory = 'pg_log'          # or your desired directory
log_filename = 'postgresql-%Y-%m-%d.csv'
log_rotation_age = 1d
log_rotation_size = 0
```

Then reload/restart PostgreSQL:

```bash
SELECT pg_reload_conf();
```

Now PostgreSQL will write logs in **CSV format** into `$PGDATA/pg_log/`.

---

## 🔹 Step 2. Create a table to read logs

Make a table that matches PostgreSQL’s `csvlog` structure. For Postgres 13+ the columns are:

```sql
CREATE TABLE pg_logs (
    log_time timestamptz,
    user_name text,
    database_name text,
    process_id int,
    connection_from text,
    session_id text,
    session_line_num bigint,
    command_tag text,
    session_start_time timestamptz,
    virtual_transaction_id text,
    transaction_id bigint,
    error_severity text,
    sql_state_code text,
    message text,
    detail text,
    hint text,
    internal_query text,
    internal_query_pos int,
    context text,
    query text,
    query_pos int,
    location text,
    application_name text
);
```

---

## 🔹 Step 3. Load the CSV logs into the table

For a daily log file (example: `postgresql-2025-08-19.csv`):

```sql
TRUNCATE pg_logs;

COPY pg_logs
FROM '/var/lib/pgsql/data/pg_log/postgresql-2025-08-19.csv'
WITH (FORMAT csv, HEADER true);
```

> ⚠️ Requires superuser or a role with `pg_read_server_files` privilege.
> If you don’t want to manually load, you can automate with a cron or foreign table (see Step 5).

---

## 🔹 Step 4. Query errors like in MySQL

Now you can query logs:

```sql
-- All errors today
SELECT log_time, error_severity, message, query
FROM pg_logs
WHERE error_severity = 'ERROR'
ORDER BY log_time DESC;

-- All slow queries (example: queries containing "duration")
SELECT log_time, message
FROM pg_logs
WHERE message LIKE 'duration:%'
ORDER BY log_time DESC;
```

---

## 🔹 Step 5. (Optional) Query logs directly without copying

You can create a **foreign table** if you don’t want to copy every day:

```sql
CREATE EXTENSION file_fdw;

CREATE SERVER pglog_fdw FOREIGN DATA WRAPPER file_fdw;

CREATE FOREIGN TABLE pg_logs_fdw (
    log_time timestamptz,
    user_name text,
    database_name text,
    process_id int,
    connection_from text,
    session_id text,
    session_line_num bigint,
    command_tag text,
    session_start_time timestamptz,
    virtual_transaction_id text,
    transaction_id bigint,
    error_severity text,
    sql_state_code text,
    message text,
    detail text,
    hint text,
    internal_query text,
    internal_query_pos int,
    context text,
    query text,
    query_pos int,
    location text,
    application_name text
)
SERVER pglog_fdw
OPTIONS (filename '/var/lib/pgsql/data/pg_log/postgresql-2025-08-19.csv', format 'csv', header 'true');
```

Now you can query:

```sql
SELECT * FROM pg_logs_fdw WHERE error_severity = 'ERROR';
```

---

✅ **Summary**

* Enable `csvlog` in `postgresql.conf`.
* Either `COPY` CSV into a table or create a **foreign table** with `file_fdw`.
* Then you can query logs with SQL filters just like in MySQL.

---

👉 Do you want me to write you a **script that automatically imports yesterday’s log file into `pg_logs`** every day, so you always have a queryable log table?

