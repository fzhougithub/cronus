#!/bin/bash

if [ $# -ne 8 ]
then
	echo
	echo "Usage:  $0 [publication_name] [subscription_name] [publisher_host] [publisher_db] [subscriber_db] [tablist_file]"
	echo "    publication_name   = name of the new publication"
	echo "    subscription_name  = name of the new subscription"
	echo "    publisher_host     = hostname or IP address of the publisher (source)"
	echo "    publisher_db       = publisher (source) database"
	echo "    subscriber_db      = subscriber (target) database"
	echo "    publisher_port     = publister (source) db port"
	echo "    subscriber_port    = subscriber (target) db port"
	echo "    tablist_file       = local file with a list of tables in the format schema.table"
	echo
	echo "Note: This script is designed to be run from the subscriber (target)"
	echo
	exit
else
	pubname="$1"
	subname="$2"
	publisher="$3"
	pub_db="$4"
	sub_db="$5"
	pub_port=$6
	sub_port=$7
	tablist="$8"
fi

echo "--| Check db connectivity"
checkSql="select count(*) from pg_stat_database"
echo "$checkSql" | psql -h ${publisher} -p ${pub_port} -t ${pub_db} > /dev/null
if [ $? -ne 0 ]
then
	echo
	echo "ERROR: Cannot connect to publisher [$publisher] via psql, aborting"
	echo
	exit
else
	echo "--| db connectivity check success!"
	echo
	echo
fi



echo "--| TRUNCATE Subscriber Tables"

if [ ! -f "$tablist" ]
then
	echo
	echo "ERROR: tablist_file [$tablist] does not exist, or is not readable, aborting"
	echo
	exit
fi

echo "[clean_tables.sh  ${sub_db}  ${tablist}]"
./clean_tables.sh  ${sub_db}  ${tablist}


echo "--| Create Publication"

if [ ! -f "$tablist" ]
then
	echo
	echo "ERROR: tablist_file [$tablist] does not exist, or is not readable, aborting"
	echo
	exit
fi

# eliminate blank lines
runTablist="tmp_${tablist}"
cat "$tablist" | sed '/^[[:space:]]*$/d' > $runTablist

#get num rows in runTablist file
tablistCntStr=$( cat $runTablist | wc -l )
set - $tablistCntStr
tablistCnt=$1

lineCntr=0
outfile="crt_pub_list_tmp.sql"
echo "CREATE PUBLICATION  ${pubname} FOR TABLE " > $outfile
for TAB in $( cat $runTablist )
do
	lineCntr=$(( $lineCntr + 1 ))
	if [ $lineCntr -lt $tablistCnt ]
	then
		echo "${crtPubSql} ${TAB} , " >> $outfile
	else
		echo "${crtPubSql} ${TAB} ;" >> $outfile
	fi
done

psql -h ${publisher} -f $outfile -p ${pub_port} -t ${pub_db}
if [ $? -ne 0 ]
then
	echo
	echo "ERROR:  Create Publication failed, aborting"
	echo
	exit
else
	echo "--| create publication success!"
	echo
	echo
fi


echo "--| Create Subscription"
crt_sub="CREATE SUBSCRIPTION ${subname} connection 'host=${publisher} dbname=${pub_db} port=${pub_port}' PUBLICATION ${pubname} ;"
echo "[$crt_sub]"


echo "$crt_sub" | psql -p ${sub_port} -t ${sub_db}
if [ $? -ne 0 ]
then
	echo
	echo "ERROR:  Create Subscription failed, aborting"
	echo
	exit
else
	echo "--| create Subscription success!"
	echo
	echo
fi

