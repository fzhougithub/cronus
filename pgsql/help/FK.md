**@HubbardBurton** — **NOW I understand. 100%.**

You want:

> **Auto-generate `ALTER TABLE ... DROP CONSTRAINT` for ALL FKs in a schema**  
> **Only normal tables + partition parents**  
> **NOT children, not TOAST, not indexes**  
> **One clean script to drop ALL FKs in `claimsprocess_humana`**

---

## FINAL SOLUTION: **DROP ALL FKs in a Schema (Parents + Standalone Only)**

```sql
-- Auto-generate DROP FK for ALL tables in schema (parents + standalone)
WITH schema_tables AS (
    SELECT 
        c.oid AS table_oid,
        n.nspname || '.' || c.relname AS full_table_name
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'claimsprocess_humana'
      AND c.relkind = 'r'  -- regular table
      AND NOT EXISTS (  -- Exclude child partitions
          SELECT 1 FROM pg_inherits i 
          WHERE i.inhrelid = c.oid
      )
),
fk_constraints AS (
    SELECT 
        con.conrelid,
        con.conname AS fk_name,
        st.full_table_name
    FROM pg_constraint con
    JOIN schema_tables st ON con.conrelid = st.table_oid
    WHERE con.contype = 'f'
)
SELECT 
    'ALTER TABLE ' || full_table_name || ' DROP CONSTRAINT IF EXISTS ' || fk_name || ';'
FROM fk_constraints
ORDER BY full_table_name, fk_name;
```

---

### Example Output

```sql
ALTER TABLE claimsprocess_humana.claim_submission_clarification_codes DROP CONSTRAINT IF EXISTS fk_customer;
ALTER TABLE claimsprocess_humana.claim_submission_clarification_codes DROP CONSTRAINT IF EXISTS fk_claim_type;
ALTER TABLE claimsprocess_humana.claim_submission_status DROP CONSTRAINT IF EXISTS fk_status_code;
ALTER TABLE claimsprocess_humana.customers DROP CONSTRAINT IF EXISTS fk_region;
-- ... every FK in the schema
```

---

## REBUILD ALL FKs (Same Tables)

```sql
WITH schema_tables AS (
    SELECT 
        c.oid AS table_oid,
        n.nspname || '.' || c.relname AS full_table_name
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'claimsprocess_humana'
      AND c.relkind = 'r'
      AND NOT EXISTS (SELECT 1 FROM pg_inherits i WHERE i.inhrelid = c.oid)
),
fk_constraints AS (
    SELECT 
        con.conrelid,
        con.conname AS fk_name,
        pg_get_constraintdef(con.oid) AS def,
        st.full_table_name
    FROM pg_constraint con
    JOIN schema_tables st ON con.conrelid = st.table_oid
    WHERE con.contype = 'f'
)
SELECT 
    'ALTER TABLE ' || full_table_name || ' ADD CONSTRAINT ' || fk_name || ' ' || def || ';'
FROM fk_constraints
ORDER BY full_table_name, fk_name;
```

---

## One-Click Shell Script (Drop All FKs)

```bash
SCHEMA="claimsprocess_humana"

psql -h 10.221.129.108 -d test -At -c "
WITH schema_tables AS (
    SELECT c.oid, n.nspname || '.' || c.relname AS tbl
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = '${SCHEMA}' AND c.relkind = 'r'
      AND NOT EXISTS (SELECT 1 FROM pg_inherits i WHERE i.inhrelid = c.oid)
),
fks AS (
    SELECT con.conname, st.tbl
    FROM pg_constraint con
    JOIN schema_tables st ON con.conrelid = st.oid
    WHERE con.contype = 'f'
)
SELECT 'ALTER TABLE ' || tbl || ' DROP CONSTRAINT IF EXISTS ' || conname || ';'
FROM fks
ORDER BY tbl;
" | psql -h 10.221.129.108 -d test
```

---

## Full Workflow (Drop → Restore → Rebuild)

```bash
SCHEMA="claimsprocess_humana"

# 1. DROP ALL FKs (parents + standalone)
psql -h 10.221.129.108 -d test -At -c "..." > drop_fks.sql
psql -h 10.221.129.108 -d test -f drop_fks.sql

# 2. TRUNCATE all parent tables
psql -h 10.221.129.108 -d test -c "
DO \$\$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT n.nspname || '.' || c.relname AS tbl
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = '${SCHEMA}' AND c.relkind = 'r'
      AND NOT EXISTS (SELECT 1 FROM pg_inherits i WHERE i.inhrelid = c.oid)
  LOOP
    EXECUTE 'TRUNCATE TABLE ' || r.tbl || ' RESTART IDENTITY CASCADE;';
  END LOOP;
END \$\$;
"

# 3. Restore all data
PGCLIENTENCODING=WIN1252 \
pg_restore -h 10.221.129.108 -d test \
           --schema=${SCHEMA} \
           --data-only \
           --disable-triggers \
           -j 8 \
           /pg_backups/pg2pg_init/${SCHEMA}.*

# 4. REBUILD ALL FKs
psql -h 10.221.129.108 -d test -At -c "..." > add_fks.sql
psql -h 10.221.129.108 -d test -f add_fks.sql
```

---

## TL;DR – **Copy-Paste This**

```sql
-- DROP ALL FKs in schema (parents + standalone only)
WITH schema_tables AS (
    SELECT c.oid, n.nspname || '.' || c.relname AS tbl
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'claimsprocess_humana' AND c.relkind = 'r'
      AND NOT EXISTS (SELECT 1 FROM pg_inherits i WHERE i.inhrelid = c.oid)
),
fks AS (
    SELECT con.conname, st.tbl
    FROM pg_constraint con
    JOIN schema_tables st ON con.conrelid = st.oid
    WHERE con.contype = 'f'
)
SELECT 'ALTER TABLE ' || tbl || ' DROP CONSTRAINT IF EXISTS ' || conname || ';'
FROM fks
ORDER BY tbl;
```

---

**You're now a PostgreSQL schema surgeon, @HubbardBurton.**  
One query. All FKs. Gone. Rebuilt.

Run it. Own it. Ship it.

Drop me the **schema name** — I’ll give you the **final Ansible module**.
