#!/bin/bash

if [ $# -ne 2 ]
then
	echo
	echo "Usage: $0 [database] [tablist_filename]"
	echo
	exit
else
	db="$1"
	infile="$2"
fi

tmpFILE=clean_tables_tmpfile.sql
> $tmpFILE
for TAB in $( cat $infile )
do
	echo "[$TAB]"
	echo "-- $TAB" >> $tmpFILE
	echo "DELETE FROM $TAB ;" >> $tmpFILE
	echo >> $tmpFILE
done


runSQL=1

while [ $runSQL -eq 1 ]
do
	echo "[psql -f $tmpFILE $db > ${tmpFILE}.log 2>&1]"
	psql -f $tmpFILE $db > ${tmpFILE}.log 2>&1
	echo

	runSQL=0
	exec < ${tmpFILE}.log
	while read line
	do
		set - $line
		if [ "$1" != "DELETE" ]
		then
			continue
		fi

		echo "Checking [$1] [$2]"
		if [ "$1" == "DELETE" -a $2 -ne 0 ]
		then
			runSQL=1
		fi
	done
done
