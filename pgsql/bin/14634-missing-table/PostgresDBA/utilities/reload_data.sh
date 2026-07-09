#!/bin/bash

if [ $# -ne 3 ]
then
	echo "Usage:  $0 [dbname] [schema] [sub-dirname]"
	echo "  WARNING: directory passed in for sub-dirname will be cleaned out"
	echo
	exit
else
	db="$1"
	sch="$2"
	dir="$3"
fi


/bin/rm -fr $dir

if [ ! -d $dir ]
then
	mkdir $dir
	if [ ! -d $dir ]
	then
		echo "ERROR: coulld not create sub-directory [$dir]"
		echo
		exit
	fi
else
	echo "ERROR: Could not remove sub-directory [$dir]"
	echo
	exit
fi

ddl_sql_file="${dir}/${db}.${sch}.DDL.sql"
pg_dump -s -n $sch $db > $ddl_sql_file

constraint_add_sql="${dir}/add_constraints.sql"
constraint_drop_sql="${dir}/drop_constraints.sql"
table_delete_sql="${dir}/delete_table_data.sql"

> $constraint_add_sql
> $constraint_drop_sql
> $table_delete_sql

grep -B1 -A1 "ADD CONSTRAINT"  $ddl_sql_file > $constraint_add_sql


exec < $constraint_add_sql
while read line
do
	if [ ${#line} -eq 0 ]
	then
		continue
	fi

	# remove leading & trailing spaces just in case
	#   even though exec should do it for us
	line_leading=$( echo "$line" | sed 's/^[[:space:]]*//' )
	line=$( echo "$line_leading" | sed 's/[[:space:]]*$//' )

	echo "$line" | grep ALTER | grep TABLE > /dev/null 2>&1
	if [ $? -eq 0 ]
	then
		alterLine="$line"
	fi

	set - $line
	if [ "$1" == "ADD" -a "$2" == "CONSTRAINT" ]
	then
		echo "$alterLine" >> $constraint_drop_sql
		echo "DROP CONSTRAINT $3 CASCADE ;" >>  $constraint_drop_sql
		echo >> $constraint_drop_sql
	fi
done


grep "CREATE TABLE"  $ddl_sql_file  > ${dir}/crt_tabs.txt
exec < ${dir}/crt_tabs.txt
while read line
do
	set - $line

	if [ "$1" == "CREATE" -a "$2" == "TABLE" ]
	then
		echo "DELETE FROM $3 ;" >> $table_delete_sql
	else
		echo "ERROR on line [$line]"
		echo "expected \$1 to be CREATE and \$2 to be TABLE"
		echo
		exit
	fi
done
/bin/rm -f ${dir}/crt_tabs.txt

echo "Execute:"
echo "psql -f ${dir}/drop_constraints.sql  $db"
echo "psql -f ${dir}/delete_table_data.sql  $db"
echo "pg_restore -Fc  -d $db  -a  -n $sch  -v  [dumpfile]"
echo "psql -f ${dir}/add_constraints.sql  $db"
