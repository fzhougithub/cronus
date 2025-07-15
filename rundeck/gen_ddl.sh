#!/bin/bash


if [ $# -ne 4 ]
then
	echo
	echo "Usage: $0 [ods dbname] [source ip] [source dbname] [schemaname]"
	echo
	exit
else
	odsDB="$1"
	remoteHost="$2"
	remoteDB="$3"
	sch="$4"
fi

PGDUMP=/usr/pgsql-14/bin/pg_dump
tmpDumpFN=/tmp/tempdumpfile.txt


echo
echo "-- remote schema section"
echo
> ${tmpDumpFN}
$PGDUMP -h ${remoteHost} -s --schema=${sch}  ${remoteDB} >  ${tmpDumpFN}

printLines=0
exec < ${tmpDumpFN}
while read line
do
	if [ $printLines -eq 1 ]
	then
		echo "$line"
	else
		if [ "$line" == "" ]
		then
			continue
		fi

		if [ "$line" == ")" ]
		then
			continue
		fi

		if [ "$line" == "(" ]
		then
			continue
		fi

		set - $line

		if [ "$1" == "SET" -a "$2" == "default_tablespace" ]
		then
			printLines=1
			echo "$line"
		fi
	fi
done

echo
echo


echo
echo "-- ods GRANT section"
echo
> ${tmpDumpFN}
$PGDUMP -s --schema=${sch}  ${odsDB} >  ${tmpDumpFN}

printLines=0
exec < ${tmpDumpFN}
while read line
do
	if [ $printLines -eq 1 ]
	then
		echo "$line"
	else
		if [ "$line" == "" ]
		then
			continue
		fi

		if [ "$line" == ")" ]
		then
			continue
		fi

		if [ "$line" == "(" ]
		then
			continue
		fi

		set - $line

		if [ "$1" == "GRANT" -o "$1" == "REVOKE" ]
		then
			printLines=1
			echo "$line"
		fi
	fi
done

echo
echo "-- misc schema section"
echo
$PGDUMP -s --schema=misc  ${odsDB}
