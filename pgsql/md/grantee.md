Ah-ha! Classic PostgreSQL permission trap! You've discovered exactly why pg_dumpall -g is insufficient for complete role backup. Let me explain what happened and how to fix it.

🔍 Root Cause Analysis

What Happened:

1. ✅ You dumped global metadata with pg_dumpall -g
2. ✅ You restored it to new database  
3. ❌ Schema datamart exists but has NO GRANTS
4. ❌ Users get "permission denied" because no one has access to the schema

Why This Happens:

• pg_dumpall -g only creates roles/users, doesn't grant any privileges

• Schema creation ≠ Schema access rights

• Your original database had specific GRANT statements that were NOT captured

🕵️ Let's Diagnose the Current State

Run these queries to see what's missing:

1. Check if Schema Exists:

-- Verify schema exists
SELECT schema_name, schema_owner 
FROM information_schema.schemata 
WHERE schema_name = 'datamart';


2. Check Role Privileges on Database:

-- See who has CONNECT privilege on the database
SELECT grantee, privilege_type
FROM information_schema.database_privileges 
WHERE grantee NOT IN ('postgres', 'PUBLIC');


3. Check Existing Roles:

-- List all roles/users
SELECT rolname, rolsuper, rolinherit, rolcreaterole, 
       rolcreatedb, rolcanlogin, rolreplication
FROM pg_roles 
WHERE rolname NOT LIKE 'pg_%' AND rolname != 'postgres';


4. Check Current Search Path:

-- See current user's search path
SHOW search_path;


🛠️ The Fix: Grant Proper Permissions

Step 1: Grant Database Connect Privilege

-- Allow users to connect to database
GRANT CONNECT ON DATABASE ods_domani TO your_app_user;
GRANT CONNECT ON DATABASE ods_domani TO your_readonly_user;
-- Replace with your actual usernames


Step 2: Grant Schema Usage and Privileges

-- Grant usage on schema
GRANT USAGE ON SCHEMA datamart TO your_app_user;
GRANT USAGE ON SCHEMA datamart TO your_readonly_user;

-- Grant table privileges (adjust based on needs)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA datamart 
TO your_app_user;

GRANT SELECT ON ALL TABLES IN SCHEMA datamart 
TO your_readonly_user;

-- Grant sequence privileges (for auto-increment IDs)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA datamart 
TO your_app_user;


Step 3: Set Default Privileges for Future Objects

-- Ensure future tables get proper permissions
ALTER DEFAULT PRIVILEGES IN SCHEMA datamart 
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO your_app_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA datamart 
GRANT SELECT ON TABLES TO your_readonly_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA datamart 
GRANT USAGE, SELECT ON SEQUENCES TO your_app_user;


Step 4: Grant Execute on Functions (if applicable)

-- If you have functions in the schema
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA datamart TO your_app_user;


🔄 Complete Permission Restoration Script

Here's a comprehensive script to fix your permissions:
-- ===========================================
-- PERMISSION RESTORATION SCRIPT FOR DATAMART
-- ===========================================

-- 1. Database level permissions
GRANT CONNECT ON DATABASE ods_domani TO app_user;      -- Replace with actual usernames
GRANT CONNECT ON DATABASE ods_domani TO readonly_user;  -- Replace with actual usernames

-- 2. Schema level permissions
GRANT USAGE ON SCHEMA datamart TO app_user;
GRANT USAGE ON SCHEMA datamart TO readonly_user;

-- 3. Table level permissions (existing tables)
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA datamart TO app_user;
GRANT SELECT ON ALL TABLES IN SCHEMA datamart TO readonly_user;

-- 4. Sequence permissions (for auto-increment columns)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA datamart TO app_user;

-- 5. Function permissions (if any exist)
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA datamart TO app_user;

-- 6. Default privileges for FUTURE objects
ALTER DEFAULT PRIVILEGES IN SCHEMA datamart 
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA datamart 
GRANT SELECT ON TABLES TO readonly_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA datamart 
GRANT USAGE, SELECT ON SEQUENCES TO app_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA datamart 
GRANT EXECUTE ON FUNCTIONS TO app_user;

-- 7. Verify the grants
SELECT 'Schema permissions:' as check_type;
SELECT grantee, privilege_type 
FROM information_schema.schema_privileges 
WHERE schema_name = 'datamart';

SELECT 'Table permissions:' as check_type;
SELECT grantee, privilege_type, table_name
FROM information_schema.table_privileges 
WHERE table_schema = 'datamart';


🔍 How to Find Original Permissions from Old Database

If you still have access to the old database, extract the exact permissions:

From Old Database - Extract Schema Grants:

-- On OLD database, run this to see what was granted:
SELECT 
    'GRANT ' || privilege_type || ' ON SCHEMA ' || schema_name || 
    ' TO ' || grantee || ';' as grant_statement
FROM information_schema.schema_privileges 
WHERE schema_name = 'datamart';

SELECT 
    'GRANT ' || privilege_type || ' ON TABLE ' || table_schema || '.' || table_name || 
    ' TO ' || grantee || ';' as grant_statement
FROM information_schema.table_privileges 
WHERE table_schema = 'datamart';

SELECT 
    'GRANT USAGE, SELECT ON SEQUENCE ' || sequence_schema || '.' || sequence_name || 
    ' TO ' || grantee || ';' as grant_statement
FROM information_schema.sequence_privileges 
WHERE sequence_schema = 'datamart';


📋 Prevention for Next Time

Use Comprehensive Backup Approach:

#!/bin/bash
# Complete backup including permissions
BACKUP_DIR="/backup/complete_$(date +%Y%m%d)"

# 1. Basic globals
pg_dumpall -g > "$BACKUP_DIR/globals.sql"

# 2. Schema-specific permissions
pg_dump -s -n datamart ods_domani > "$BACKUP_DIR/datamart_schema.sql"

# 3. All privileges on datamart schema
psql -d ods_domani -c "\z datamart.*" > "$BACKUP_DIR/datamart_privileges.txt"

# 4. Role memberships and detailed privileges
psql -d ods_domani -f - > "$BACKUP_DIR/detailed_roles.sql" <<EOF
-- Export all GRANT statements for datamart
SELECT 'GRANT ' || privilege_type || ' ON ALL ' || 
       CASE classid 
           WHEN 'pg_class'::regclass THEN 'TABLES'
           WHEN 'pg_namespace'::regclass THEN 'SCHEMAS'
       END || ' IN SCHEMA datamart TO ' || grantee || ';'
FROM (
    SELECT DISTINCT privilege_type, classid, grantee
    FROM pg_class c
    JOIN pg_namespace n ON c.relnamespace = n.oid
    JOIN aclexplode(c.relacl) a ON true
    WHERE n.nspname = 'datamart' AND grantee NOT IN ('postgres', 'PUBLIC')
) grants;
EOF


✅ Quick Test After Applying Fix

Have users test with:
-- Test schema access
SET search_path TO datamart, public;

-- Test table access
SELECT * FROM your_table LIMIT 1;  -- Replace with actual table name


Bottom Line: pg_dumpall -g creates users but doesn't give them any permissions. You must explicitly GRANT access to schemas, tables, and sequences. This is a very common oversight in PostgreSQL migrations! 🎯
