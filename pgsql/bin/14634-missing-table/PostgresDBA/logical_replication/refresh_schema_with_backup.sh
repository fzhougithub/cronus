#!/bin/bash

if [ $# -ne 6 ]
then
    echo
    echo "Usage: $0 [environment] [schema] [source_ip] [source_db] [target_db] [target_schema]"
    echo "    environment     = e.g., rtl"
    echo "    schema          = source schema name, e.g., pct"
    echo "    source_ip       = IP address of the source server, e.g., 10.222.233.102"
    echo "    source_db       = source database name, e.g., pct"
    echo "    target_db       = target database name (always ods_domani)"
    echo "    target_schema   = target schema name (usually same as schema)"
    echo
    echo "Note: This script automates the logical replication setup process."
    echo "      Ports are hardcoded to 5432 for both source and target."
    echo "      Run this script from the target subscription server."
    echo
    exit
else
    env="$1"
    schema="$2"
    source_ip="$3"
    source_db="$4"
    target_db="$5"
    target_schema="$6"
    port=5432
fi

# Construct names
pub_name="${env}_${schema}_pub"
sub_name="${env}_${schema}_sub"
ddl_file="${schema}_ddc.sql"
tablist_file="${schema}.tablist"
backup_file="${target_schema}_schema_backup_$(date +%Y%m%d_%H%M%S).sql"

# Step 0: Dump schema-only backup from ods_domani (target_db) locally
echo "--| Checking if schema ${target_schema} exists in ${target_db}"
schema_exists=$(psql -t -d ${target_db} -p ${port} -c "SELECT 1 FROM pg_namespace WHERE nspname = '${target_schema}';" | grep -v "^$")

if [ -z "${schema_exists}" ]; then
    echo "WARNING: Schema ${target_schema} not found in ${target_db}. Skipping backup step."
    backup_skipped=true
else
    echo "--| Creating schema-only backup of ${target_schema} from ${target_db}"
    pg_dump -d ${target_db} -p ${port} -n ${target_schema} --schema-only -f ${backup_file}

    if [ $? -eq 0 ]; then
        echo "Schema backup saved to: ${backup_file}"
        backup_skipped=false
    else
        echo "ERROR: Failed to create schema backup. Exiting."
        exit 1
    fi
fi

# Step 1: On target database - Drop matching subscriptions and schemas
echo "--| Checking and dropping matching subscriptions and schemas on target DB: ${target_db}"

# Find and drop subscriptions like %${schema}%
sub_query="SELECT subname FROM pg_subscription WHERE subname ILIKE '%${schema}%';"
subs=$(psql -t -d ${target_db} -p ${port} -c "${sub_query}" | grep -v "^$")
for sub in ${subs}; do
    echo "Dropping subscription: ${sub}"
    psql -d ${target_db} -p ${port} -c "DROP SUBSCRIPTION IF EXISTS ${sub};"
done

# Find and drop schemas like %${schema}%
schema_query="SELECT nspname FROM pg_namespace WHERE nspname ILIKE '%${schema}%' AND nspname NOT IN ('information_schema', 'pg_catalog', 'pg_toast');"
schemas=$(psql -t -d ${target_db} -p ${port} -c "${schema_query}" | grep -v "^$")
for sch in ${schemas}; do
    echo "Dropping schema: ${sch} CASCADE"
    psql -d ${target_db} -p ${port} -c "DROP SCHEMA IF EXISTS ${sch} CASCADE;"
done

# Step 2: On source database - Drop matching publications
echo "--| Checking and dropping matching publications on source DB: ${source_db} at ${source_ip}"

pub_query="SELECT pubname FROM pg_publication WHERE pubname ILIKE '%${schema}%';"
pubs=$(psql -t -h ${source_ip} -d ${source_db} -p ${port} -c "${pub_query}" | grep -v "^$")
for pub in ${pubs}; do
    echo "Dropping publication: ${pub}"
    psql -h ${source_ip} -d ${source_db} -p ${port} -c "DROP PUBLICATION IF EXISTS ${pub};"
done

# Note: Do not drop schema on source

# Step 3: Dump DDL from source
echo "--| Dumping DDL from source"
./gen_ddl.sh ${target_db} ${source_ip} ${source_db} ${schema} > ${ddl_file}

# Step 4: Restore DDL to target schema
echo "--| Restoring DDL to target schema: ${target_schema} in ${target_db}"
psql -d ${target_db} -p ${port} -c "CREATE SCHEMA IF NOT EXISTS ${target_schema};"
psql -d ${target_db} -p ${port} -c "SET search_path TO ${target_schema};" -f ${ddl_file}

# Step 5: Generate table list
echo "--| Generating table list for schema: ${target_schema}"
./gen_full_tablist.sh ${target_db} ${target_schema} > ${tablist_file}

# Step 6: Restore schema backup before deploying logical replication
if [ "${backup_skipped}" = true ]; then
    echo "--| Skipping schema restore (backup was not created)"
else
    echo "--| Restoring schema backup to ${target_schema} in ${target_db}"
    psql -d ${target_db} -p ${port} -f ${backup_file}

    if [ $? -eq 0 ]; then
        echo "Schema backup restored successfully"
    else
        echo "WARNING: Schema restore encountered issues, but continuing..."
    fi
fi

# Step 7: Deploy logical replication
echo "--| Deploying logical replication"
./deploy_logical_replication.sh ${pub_name} ${sub_name} ${source_ip} ${source_db} ${target_db} ${port} ${port} ${tablist_file}

echo "--| Automation completed successfully!"
