#!/bin/bash

#-----------------------------------------------
#-| collapse_table.sh
#-----------------------------------------------
#-| This script is designed to convert 
#-|  a partitioned table into a flat / single
#-|  table.
#-| The script will perform the following steps:
#-|  - Validate parameters (db, schema and table)
#-|  - Verify the "new" table (tablename_new)
#-|       does not exist
#-|  - Create the "new" table
#-|  - Start a Transaction and perform the following:
#-|     > Set the search_path to the passed in schema
#-|     > LOCK the partitioned base table
#-|     > Migrate all data to the new table
#-|     > RENAME the partitioned table to (table)_old
#-|     > RENAME the new table from (table)_new to (table)
#-----------------------------------------------

if [ $# -ne 3 ]
then
	echo
	echo "Usage: $0 [dbname] [schema] [table]"
	echo
	exit
else
	db="$1"
	sch="$2"
	tab="$3"
fi

PGBIN=/usr/pgsql-14/bin

#-- Validate database
echo "#--|  Validating database [$db]"
dbcheckSQL="select count(*) from pg_database where datname = '$db'"
dbcheckSTR=$( echo "$dbcheckSQL" | ${PGBIN}/psql -t postgres )
set - $dbcheckSTR
dbcheck=$1

if [ $dbcheck -ne 1 ]
then
	echo
	echo "ERROR: database [$db] does not exist, aborting"
	echo
	exit
else
	echo "     -- Database [$db] verified."
fi

echo "#--|  Done"
echo
echo


#-- Validate schema
echo "#--|  Validating Schema [$sch]"
schemacheckSQL="select count(*) from pg_namespace where nspname = '$sch'"
schemacheckSTR=$( echo "$schemacheckSQL" | ${PGBIN}/psql -t $db )
set - $schemacheckSTR
schemacheck=$1

if [ $schemacheck -ne 1 ]
then
	echo
	echo "ERROR: schema [$sch] does not exist, aborting"
	echo
	exit
else
	echo "     -- Schema [$sch] verified."
fi

echo "#--|  Done"
echo
echo



#-- Validate table
echo "#--|  Validating Table [$tab]"
tabcheckSQL="select count(*) from pg_tables where schemaname = '$sch' and tablename = '$tab'"
tabcheckSTR=$( echo "$tabcheckSQL" | ${PGBIN}/psql -t $db )
set - $tabcheckSTR
tabcheck=$1

if [ $tabcheck -ne 1 ]
then
	echo
	echo "ERROR: tab [${sch}.${tab}] does not exist, aborting"
	echo
	exit
else
	echo "     -- Table [${sch}.${tab}] verified."
fi

echo "#--|  Done"
echo
echo


newtab="${sch}.${tab}_new"

#-- new table check
echo "#--|  Validate New Table [$newtab] does not exist"
newtabcheckSQL="select count(*) from pg_tables where schemaname = '$sch' and tablename = '${tab}_new'"
newtabcheckSTR=$( echo "$newtabcheckSQL" | ${PGBIN}/psql -t $db )
set - $newtabcheckSTR
newtabcheck=$1

if [ $newtabcheck -ne 0 ]
then
	echo
	echo "ERROR: newtab [$newtab] exists, aborting"
	echo
	exit
else
	echo "     -- Table [$newtab] does not exist."
fi

echo "#--|  Done"
echo
echo


#-- Create new table
echo "#--|  Create New Table [$newtab]"
createnewtabSQL="CREATE TABLE $newtab ( LIKE ${sch}.${tab} INCLUDING ALL )"
echo "$createnewtabSQL" |  ${PGBIN}/psql -t $db
echo "#--|  Done"
echo
echo

#-- new table check
echo "#--|  Validate New Table [$newtab] was created successfully"
newtabcheckSQL="select count(*) from pg_tables where schemaname = '$sch' and tablename = '${tab}_new'"
newtabcheckSTR=$( echo "$newtabcheckSQL" | ${PGBIN}/psql -t $db )
set - $newtabcheckSTR
newtabcheck=$1

if [ $newtabcheck -ne 1 ]
then
	echo
	echo "ERROR: newtab [$newtab] was not created, aborting"
	echo
	exit
else
	echo "     -- Table [$newtab] was created."
fi

echo "#--|  Done"
echo
echo


${PGBIN}/psql -e $db <<!
	BEGIN ;
	SET search_path = $sch ;
	LOCK TABLE ${sch}.${tab} ;
	INSERT INTO $newtab SELECT * FROM ${sch}.${tab} ;
	ALTER TABLE ${tab} RENAME TO ${tab}_old ;
	ALTER TABLE ${tab}_new RENAME TO ${tab} ;
	COMMIT ;
!
