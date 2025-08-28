Checking all object ownership in PostgreSQL is a crucial security and management task. You'll primarily use the `psql` command-line client and query PostgreSQL's system catalogs.

Here's a comprehensive approach:

### 1\. Using `psql` Meta-Commands (Quick & Easy)

`psql` provides convenient meta-commands to list objects and their owners. This is often the quickest way to get an overview.

  * **Connect to your database:**

    ```bash
    psql -U your_user -d your_database -h your_host
    ```

    (Replace `your_user`, `your_database`, `your_host` with actual values)

  * **List Databases and Owners:**

    ```sql
    \l+
    ```

    This lists all databases, their owners, and other details. Look at the "Owner" column.

  * **List Schemas and Owners:**

    ```sql
    \dn+
    ```

    This lists all schemas in the current database and their owners.

  * **List Tables, Views, Materialized Views, and Sequences (and their owners) in the current database:**

    ```sql
    \d+
    ```

    This is a very comprehensive command. It lists tables, views, materialized views, and sequences. The "Owner" column will show who owns each. You might need to scroll a lot for large databases.

  * **List Functions/Procedures and Owners:**

    ```sql
    \df+
    ```

    This lists all functions and procedures and their owners.

  * **List Tablespaces and Owners:**

    ```sql
    \db+
    ```

    This lists all tablespaces and their owners.

  * **List Foreign Data Wrappers, Servers, and Owners:**

    ```sql
    \dew+
    \des+
    ```

  * **List Types and Domains and Owners:**

    ```sql
    \dT+
    \dD+
    ```

  * **List Publications and Subscriptions:**
    These don't have a direct `\d` command for ownership, but you can see them. Their ownership is typically tied to the creating user.

    ```sql
    \dRp+ # Publications
    \dRs+ # Subscriptions
    ```

### 2\. Querying System Catalogs (Comprehensive & Scriptable)

For a more programmatic or detailed check, especially if you want to filter or aggregate results, you'll query the `pg_catalog` tables directly. This requires `SELECT` privileges on these tables (which `postgres` superuser has by default).

**General Approach:**
Most objects have a corresponding system catalog table (e.g., `pg_class` for tables/views/sequences, `pg_namespace` for schemas, `pg_database` for databases, `pg_proc` for functions/procedures). These tables often have an `owner` or `relowner` (for relations) column, which stores the OID (Object Identifier) of the owning role. You'll join this with `pg_roles` to get the role name.

Here are some common examples:

  * **All Databases and their Owners:**

    ```sql
    SELECT
        d.datname AS database_name,
        pg_catalog.pg_get_userbyid(d.datdba) AS owner_name
    FROM
        pg_catalog.pg_database d
    ORDER BY
        database_name;
    ```

  * **All Schemas and their Owners (in the current database):**

    ```sql
    SELECT
        n.nspname AS schema_name,
        pg_catalog.pg_get_userbyid(n.nspowner) AS owner_name
    FROM
        pg_catalog.pg_namespace n
    WHERE
        n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
    ORDER BY
        schema_name;
    ```

  * **All Tables and Views and their Owners (in the current database, excluding system schemas):**

    ```sql
    SELECT
        n.nspname AS schema_name,
        c.relname AS object_name,
        CASE c.relkind
            WHEN 'r' THEN 'table'
            WHEN 'v' THEN 'view'
            WHEN 'm' THEN 'materialized view'
            WHEN 'S' THEN 'sequence'
            WHEN 'f' THEN 'foreign table'
            ELSE c.relkind::text
        END AS object_type,
        pg_catalog.pg_get_userbyid(c.relowner) AS owner_name
    FROM
        pg_catalog.pg_class c
    JOIN
        pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE
        c.relkind IN ('r', 'v', 'm', 'S', 'f')
        AND n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
    ORDER BY
        schema_name, object_type, object_name;
    ```

  * **All Functions/Procedures and their Owners (in the current database, excluding system schemas):**

    ```sql
    SELECT
        n.nspname AS schema_name,
        p.proname AS function_name,
        pg_catalog.pg_get_userbyid(p.proowner) AS owner_name
    FROM
        pg_catalog.pg_proc p
    JOIN
        pg_catalog.pg_namespace n ON n.oid = p.pronamespace
    WHERE
        n.nspname NOT LIKE 'pg_%' AND n.nspname <> 'information_schema'
    ORDER BY
        schema_name, function_name;
    ```

  * **All Tablespaces and their Owners:**

    ```sql
    SELECT
        t.spcname AS tablespace_name,
        pg_catalog.pg_get_userbyid(t.spcowner) AS owner_name
    FROM
        pg_catalog.pg_tablespace t
    ORDER BY
        tablespace_name;
    ```

### 3\. Using `REASSIGN OWNED BY` (for cleanup/transfer)

While not for "checking," the `REASSIGN OWNED BY` command (and its counterpart `DROP OWNED BY`) is invaluable for managing ownership, especially when a role is being removed. If you run `DROP ROLE some_user;` and it fails because `some_user` owns objects, the error message will often list the object types and names, which can help you identify them.

```sql
-- Example: Reassign all objects owned by 'old_user' to 'new_user' in the current database
REASSIGN OWNED BY old_user TO new_user;

-- Example: Drop all objects owned by 'old_user' in the current database
-- USE WITH EXTREME CAUTION! This will delete data.
DROP OWNED BY old_user;
```

### Best Practices for Ownership Management:

  * **Dedicated Ownership Roles:** Avoid having individual developers or application users directly own objects in production. Instead, create dedicated "ownership roles" (e.g., `app_owner`, `data_warehouse_owner`). All objects created by the application or deployment scripts should be owned by these roles.
  * **Default Privileges:** Use `ALTER DEFAULT PRIVILEGES` to automatically grant common permissions (like `SELECT` for read-only users) on new objects created by a specific role.
  * **Regular Audits:** Periodically run ownership checks, especially after major deployments or user changes, to ensure objects are owned by the correct roles.
  * **Deployment Automation:** Ensure your deployment scripts explicitly set object ownership (using `ALTER ... OWNER TO ...`) rather than relying on the creating user.
  * **Superuser Caution:** Superusers bypass all permission checks. Use them sparingly and only for administrative tasks.

By combining `psql` meta-commands for quick checks and direct system catalog queries for detailed, scriptable audits, you can effectively monitor and manage object ownership in your PostgreSQL environment.
