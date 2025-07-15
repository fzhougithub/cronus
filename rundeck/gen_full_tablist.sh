#!/bin/bash

if [ $# -ne 2 ]
then
	echo
	echo "Usage: $0 [dbname] [schemaname]"
	echo
	exit
else
	db="$1"
	sch="$2"
fi

PSQL=/usr/pgsql-14/bin/psql

SQL="SELECT schemaname || '.' || tablename FROM pg_tables WHERE schemaname = '${sch}'"
echo "$SQL" | $PSQL -t $db | grep -v "^$"
