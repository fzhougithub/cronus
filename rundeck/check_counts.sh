#!/bin/bash


if [ $# -ne 4 ]
then
        echo
        echo "Usage: $0 [tablist_file] [publisher_IP] [publisher_dbname] [outfile]"
        echo
        exit
else
        tablist="$1"
        pubIP="$2"
        pub_db="$3"
	outFile="$4"
fi

> ${outFile}

echo "CREATE SCHEMA IF NOT EXISTS chk_count" | psql postgres

echo "DROP TABLE IF EXISTS chk_count.lr_counts_tmp" | psql postgres

echo "CREATE TABLE chk_count.lr_counts_tmp (tablename varchar, pub_count int, sub_count int)" | psql postgres

for I in $( cat $tablist )
do
        sql="select count(*) from $I"
        pub_number_str=$( echo "$sql" | psql -t -h $pubIP $pub_db )
        set - $pub_number_str
        pub_number=$1
        ods_number_str=$( echo "$sql" | psql -t ods_domani )
        set - $ods_number_str
        ods_number=$1
        echo "INSERT INTO chk_count.lr_counts_tmp VALUES ('$I', $pub_number, $ods_number)" | psql postgres
        #echo -e "[$I]\t[$pub_number]\t[$ods_number]"

done

#echo "select * from chk_count.lr_counts_tmp where pub_count > 0 order by sub_count desc" | psql postgres
echo "\"select *, (pub_count - sub_count) AS pub_minus_sub_diff from chk_count.lr_counts_tmp  order by sub_count desc\" | psql postgres > ${outFile}"
echo "select *, (pub_count - sub_count) AS pub_minus_sub_diff from chk_count.lr_counts_tmp  order by sub_count desc" | psql postgres > ${outFile}

echo "DROP SCHEMA IF EXISTS chk_count CASCADE" | psql postgres
