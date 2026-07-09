#!/bin/bash

function print_usage {
    echo
    echo "Usage:  $0 [options]"
    echo
    echo "Options:"
    echo "-h   print usage"
    echo "-p   [publication name] [Required]"
    echo "-s   [subscription name] [Required]"
    echo "-n   [schema name (namespace)] [Required]"
    echo "-d   [publisher dbname] [Required]"
    echo "-H   [publisher hostname] [Required]"
    echo "-c   create new logical replication"
    echo "-r   reset logical replication"
    echo "-t   [tablist file] reset specific tables"
	echo
	echo "   NOTE: one of the -c -r or -t flags must be specified [Mutually Exclusive]"
    echo
}


pubName="_NONE_"
subName="_NONE_"
schemaName="_NONE_"
dbName="_NONE_"
hostIP="_NONE_"
hostName="_NONE_"
runMode=0
createMode=0
resetAllMode=0
resetTableMode=0
resetTabList="_NONE_"

# hard coded variables
subDB="ods_domani"
schemaOwner="dba_admin"

pgdumpCMD=/usr/pgsql-14/bin/pg_dump


while getopts ":hp:s:n:d:H:crt:" opt;
do
    case ${opt} in
        h)
            print_usage
            exit
            ;;

        p)
            pubName="${OPTARG}"
            ;;

        s)
            subName="${OPTARG}"
            ;;

        n)
            schemaName="${OPTARG}"
            ;;

        d)
            dbName="${OPTARG}"
            ;;

        H)
            hostName="${OPTARG}"
            ;;

        c)
            createMode=1
            ;;

        r)
            resetAllMode=1
            ;;

        t)
            resetTableMode=1
            resetTabList="${OPTARG}"
            ;;

        :)
            echo  "Option -${OPTARG} requires an argument."
            exit 1
            ;;

        ?)
            echo "Invalid option: -${OPTARG}."
            exit 1
            ;;

    esac
done


if [ "$pubName" == "_NONE_" ]
then
    echo 
    echo "ERROR:   [-p  publication name] is Required"
    echo
    print_usage
    exit
fi

if [ "$subName" == "_NONE_" ]
then
    echo 
    echo "ERROR:   [-s  subscription name] is Required"
    echo
    print_usage
    exit
fi

if [ "$schemaName" == "_NONE_" ]
then
    echo 
    echo "ERROR:   [-n  schema name (namespace)] is Required"
    echo
    print_usage
    exit
fi

if [ "$dbName" == "_NONE_" ]
then
    echo 
    echo "ERROR:   [-d  publisher name] is Required"
    echo
    print_usage
    exit
fi

if [ "$hostName" == "_NONE_" ]
then
    echo 
    echo "ERROR:   [-H  publisher hostname] is Required"
    echo
    print_usage
    exit
fi

if [ $createMode -eq 0 -a $resetAllMode -eq 0 -a $resetTableMode -eq 0 ]
then
    echo 
	echo "ERROR: one of the -c -r or -t flags must be specified [Mutually Exclusive]"
    echo
    print_usage
    exit
fi


if [ $resetTableMode -eq 1 -a "$resetTabList" == "_NONE_" ]
then
	echo 
	echo "If [ -t reset tabs] is specified, then resetTabList is required"
	echo
	print_usage
	exit
fi


hostIPstr=$( nslookup ${hostName} | grep Address | tail -1 )
set - $hostIPstr
hostIP="$2"

echo "pubName        [$pubName]"
echo "subName        [$subName]"
echo "schemaName     [$schemaName]"
echo "dbName         [$dbName]"
echo "hostName       [$hostName]"
echo "hostIP         [$hostIP]"
echo "runMode        [$runMode]"
echo "createMode     [$createMode]"
echo "resetAllMode   [$resetAllMode]"
echo "resetTableMode [$resetTableMode]"
echo "resetTabList   [$resetTabList]"
echo "subDB          [$subDB]"
echo
echo
echo "--"
echo
echo


#-- Create or Reset
if [ ${createMode} -eq 1 -o ${resetAllMode} -eq 1 ]
then

	# drop subscription and publication
	echo
	echo
	echo
	echo "DROP SUBSCRIPTION IF EXISTS ${subName}" | psql -e ${subDB}
	echo
	echo "DROP PUBLICATION IF EXISTS ${pubName}" | psql -e -h ${hostIP} ${dbName}
	echo
	echo "--"
	echo
	echo


	# create ods schema
	echo "CREATE SCHEMA IF NOT EXISTS ${schemaName} AUTHORIZATION ${schemaOwner}" | psql -e ${subDB}
	echo
	echo "--"
	echo
	echo



	# gen dependancy restore
	dependantSQL="SELECT distinct dependent_ns.nspname || '.' || dependent_view.relname
					FROM pg_depend
					JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid
					JOIN pg_class as dependent_view ON pg_rewrite.ev_class = dependent_view.oid
					JOIN pg_class as source_table ON pg_depend.refobjid = source_table.oid
					JOIN pg_attribute ON pg_depend.refobjid = pg_attribute.attrelid
						AND pg_depend.refobjsubid = pg_attribute.attnum
						JOIN pg_namespace dependent_ns ON dependent_ns.oid = dependent_view.relnamespace
						JOIN pg_namespace source_ns ON source_ns.oid = source_table.relnamespace
						WHERE
						source_ns.nspname = '${schemaName}'
						"

	
	echo "$dependantSQL" | psql -t ${subDB} | grep -v "^$" > /tmp/deplist
	echo
	echo "--"
	echo
	echo


	# gen dependancy restore
	pgdumpSTR="${pgdumpCMD}"
	for I in $( cat /tmp/deplist )
	do
		pgdumpSTR="${pgdumpSTR} -t ${I}"
	done
	echo "gen views.sql to restore views"
	${pgdumpSTR} ${subDB} > views.sql
	echo
	echo "--"
	echo
	echo


	echo "Drop Views"
	for I in $( cat /tmp/deplist )
	do
		echo "DROP VIEW ${I}" | psql -t ${subDB}
	done
	echo
	echo "--"
	echo
	echo


	# drop & recreate schema
	echo "Generate perms"
	${pgdumpCMD} -s --section=post-data --schema=${schemaName} ${subDB} > ${schemaName}.perms.sql
	echo
	echo "--"
	echo
	echo
	echo "DROP SCHEMA IF EXISTS ${schemaName} CASCADE" | psql -e ${subDB}
	echo
	echo "--"
	echo
	echo
	echo "CREATE SCHEMA IF NOT EXISTS ${schemaName} AUTHORIZATION ${schemaOwner}" | psql -e ${subDB}
	echo
	echo "--"
	echo
	echo


	echo "Pull pub ddl to subscriber"
	echo "[${pgdumpCMD} -s --schema=${schemaName} -h ${hostIP} ${dbName} | psql ${subDB}]"
	${pgdumpCMD} -s --schema=${schemaName} -h ${hostIP} ${dbName} | psql ${subDB}
	echo
	echo "--"
	echo
	echo

	# restore perms
	echo "restore perms"
	psql -f ${schemaName}.perms.sql ${subDB}
	echo
	echo "--"
	echo
	echo

	# restore the views
	echo "restore views"
	psql -f views.sql ${subDB}
	echo
	echo "--"
	echo
	echo


	# generate the publication
	echo "Generate PUB"
	publistSQL="SELECT n.nspname || '.' || c.relname
					FROM   pg_catalog.pg_class c
					JOIN   pg_catalog.pg_namespace n ON n.oid = c.relnamespace
					WHERE  c.relkind = ANY ('{p,r,\"\"}')
					AND    NOT c.relispartition
					AND    n.nspname = '${schemaName}'
	"

	echo "$publistSQL" | psql -t -h ${hostIP} ${dbName} | grep -v "^$" > /tmp/publist
	echo
	echo "--"
	echo
	echo


	count_str=$( wc -l /tmp/publist )
	set - $count_str
	publistRows=$1

	echo "CREATE PUBLICATION ${pubName} FOR TABLE" > crt_pub.sql
	echo

	loopCntr=1
	for I in $( cat /tmp/publist )
	do
		if [ $loopCntr -ne $publistRows ]
		then
			echo "$I ," >> crt_pub.sql
		else
			echo "$I ;" >> crt_pub.sql
		fi

		loopCntr=$(( $loopCntr + 1 ))
	done

	psql -ef crt_pub.sql -h ${hostIP} ${dbName}
	echo
	echo "--"
	echo
	echo
	 


	# generate the subscription

	echo "Generate SUB"
	subSQL="CREATE SUBSCRIPTION ${subName}
	         CONNECTION 'host=${hostIP} dbname=${dbName}'
			 PUBLICATION ${pubName}
		 "
	echo "$subSQL" | psql -e ${subDB}
	echo
	echo "--"
	echo
	echo


fi




#-- Reset tables
echo
echo
if [ ${resetTableMode} -eq 1 ]
then
	if [ ! -r "$resetTabList" ]
	then
		echo "ERROR: resetTabList [$resetTabList] does not exist, or is un-readable"
		echo "Aborting"
		echo
		exit
	fi

	# drop tables
	echo "Drop tables from PUB"
	for I in $( cat $resetTabList )
	do
		echo "ALTER PUBLICATION ${pubName} DROP TABLE ${I}" | psql -e -h ${hostIP} ${dbName}
	done
	echo
	echo "--"
	echo
	echo

	# refresh subscription
	echo "Refresh PUB"
	echo "ALTER SUBSCRIPTION ${subName} REFRESH PUBLICATION" | psql -e  ${subDB}
	echo
	echo "--"
	echo
	echo

	# add tables
	echo "Re-ADD tables TO PUB"
	for I in $( cat $resetTabList )
	do
		echo "ALTER PUBLICATION ${pubName} ADD TABLE ${I}" | psql -e -h ${hostIP} ${dbName}
	done
	echo
	echo "--"
	echo
	echo

	# refresh subscription
	echo "Refresh PUB"
	echo "ALTER SUBSCRIPTION ${subName} REFRESH PUBLICATION" | psql -e  ${subDB}
	echo
	echo "--"
	echo
	echo

fi

# cleanup
/bin/rm -f crt_pub.sql
/bin/rm -f views.sql
