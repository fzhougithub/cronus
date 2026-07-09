#!/bin/bash

if [ $# -ne 2 -a $# -ne 3 ]
then
	echo 
	echo "Usage: $0 [dbname] [schemaname] {optional: remote_ip}"
	echo
	exit
else
	db="$1"
	sch="$2"
	if [ $# -eq 3 ]
	then
		remoteCheck=1
		remoteIP="$3"
	else
		remoteCheck=0
	fi

	dtSTR=$( date +%Y%m%d%S%s )
	tmpTAB=${sch}.temp_row_check_${dtSTR}
fi

if [ $remoteCheck -eq 1 ]
then
	crt_tab_sql="CREATE TABLE $tmpTAB ( tabname varchar, local_count bigint, remote_count bigint )"
else
	crt_tab_sql="CREATE TABLE $tmpTAB ( tabname varchar, local_count bigint )"
fi

echo "$crt_tab_sql" | psql $db > /dev/null


SQL="SELECT schemaname || '.' || tablename 
	FROM pg_tables 
	WHERE schemaname = '$sch' 
	ORDER by 1"

for I in $( echo "$SQL" | psql -t $db )
do
	count_num=0
	remote_count_num=0


	if [ "$I" == "${tmpTAB}" ]
	then
		continue
	fi

	num_str=$( echo "SELECT count(*) FROM $I" | psql -t $db )
	set - $num_str
	count_num=$1

	if [ $remoteCheck -eq 1 ]
	then
		remote_num_str=$( echo "SELECT count(*) FROM $I" | psql -t -h $remoteIP $db )
		set - $remote_num_str
		remote_count_num=$1
		ins_sql="INSERT INTO $tmpTAB VALUES ( '$I', $count_num , $remote_count_num )"
	else
		ins_sql="INSERT INTO $tmpTAB VALUES ( '$I', $count_num )"
	fi

	echo "$ins_sql" | psql -t $db > /dev/null
done

view_sql="SELECT * FROM $tmpTAB order by 2 DESC"
echo "$view_sql" | psql $db

drp_tab_sql="DROP TABLE $tmpTAB "
echo "$drp_tab_sql" | psql $db > /dev/null

tab_chk_sql1="select count(*) 
				from pg_tables 
				where schemaname = '$sch' 
				and tablename like 'temp_row_check_%'"

tab_chk_sql2="select schemaname || '.' || tablename 
				from pg_tables 
				where schemaname = '$sch' 
				and tablename like 'temp_row_check_%'"

orphan_count_str=$( echo "$tab_chk_sql1" | psql -t $db )
set - $orphan_count_str
orphan_tab_count=$1

if [ $orphan_tab_count -gt 0 ]
then
	echo "Possible orphaned check_counts tables found:"
	echo
	echo "$tab_chk_sql2" | psql -t $db
fi
