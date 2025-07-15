#!/bin/bash


sqlRunFile=./run.sql
PSQL=/usr/pgsql-14/bin/psql
db=postgres
log_dir=/var/lib/pgsql/SSINC/logical_repl_monitor/uatpls


> $sqlRunFile
currLOG=$( ls -1tr ${log_dir}/*.log | tail -1 )
echo "currLOG [$currLOG]"

logROWSstr=$( wc -l $currLOG )
echo "logROWSstr [$logROWSstr]"

set - $logROWSstr
logROWS=$1

if [ -f "./log_status.txt" ]
then
        echo
		set - $logROWSstr
		currLogsize=$1
		currLogfile="$2"

		logStatusStr=$( cat ./log_status.txt )
		echo "logStatusStr [$logStatusStr]"

		set - $logStatusStr
		prevLogsize=$1
		prevLogfile="$2"

		if [ "$prevLogfile" == "$currLogfile" ]
		then
			logSegment=$(( $currLogsize - $prevLogsize ))
			echo "logSegment [$logSegment]"
			cat $currLogfile | head -${currLogsize} | tail -${logSegment} > debug_parse.log
			cat $currLogfile | head -${currLogsize} | tail -${logSegment} | grep ERROR: > parse.log
			echo "$logROWSstr" > log_status.txt
		else
			echo "new logfile"
			# get last segment of prev logfile
			prevLogTTLStr=$( wc -l $prevLogfile )
			echo "prevLogTTLStr [$prevLogTTLStr]"
			set - $prevLogTTLStr
			prevLogSize=$1
			echo "prevLogSize [$prevLogSize]"

			prevSegment=$(( $prevLogSize - $prevLogsize ))
			echo "prevSegment [$prevSegment]"

			echo "cat $prevLogfile | tail -${prevSegment} > debug_parse.log"
			echo "cat $prevLogfile | tail -${prevSegment} | grep ERROR: > parse.log"
			cat $prevLogfile | tail -${prevSegment} > debug_parse.log
			cat $prevLogfile | tail -${prevSegment} | grep ERROR: > parse.log

			# get first / current segment of new logfile
			echo "$logROWSstr" > log_status2.txt
			set - $logROWSstr
			currSize=$1
			echo "logROWSstr [$logROWSstr]"
			echo "currSize [$currSize]"

			echo "cat $currLOG | head -${currSize} >> debug_parse.log"
			echo "cat $currLOG | head -${currSize} | grep ERROR: >> parse.log"
			cat $currLOG | head -${currSize} >> debug_parse.log
			cat $currLOG | head -${currSize} | grep ERROR: >> parse.log
		fi
else
        echo "$logROWSstr" > log_status.txt
		set - $logROWSstr
		currSize=$1
		cat $currLOG | head -${currSize} > debug_parse.log
		cat $currLOG | head -${currSize} | grep ERROR: > parse.log
fi

tzSET=0
exec < parse.log
while read line
do
        set - $line
        insTS="$1 $2"
		insTZ="$3"
        shift
        shift
        shift
        insErrStr="$*"

		if [ $tzSET -eq 0 ]
		then
			setTZstr=""
			case $insTZ in
				UTC)
					setTZstr="SET timezone TO 'UTC' ;"
					;;

				EST)
					setTZstr="SET timezone TO 'America/New_York' ;"
					;;

				CST)
					setTZstr="SET timezone TO 'America/Chicago' ;"
					;;

				MST)
					setTZstr="SET timezone TO 'America/Denver' ;"
					;;

				PST)
					setTZstr="SET timezone TO 'America/Los_Angeles' ;"
					;;

				*)
					setTZstr="SET timezone TO 'UTC' ;"
					;;

			esac
			echo "$setTZstr" > $sqlRunFile
			tzSET=1
		fi

        insertSTR=" INSERT INTO misc.pg_log_errors (pg_log_error_ts, pg_log_tz, pg_log_errstr) VALUES ('${insTS}',   '${insTZ}' ,  '${insErrStr}'); "

		echo "$insertSTR"  >> $sqlRunFile
done

$PSQL -ef $sqlRunFile  ${db}
