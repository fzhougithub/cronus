#!/bin/bash


pubHostIP="NONE"
schemaName="NONE"
publisherDB="NONE"
subscriberDB="NONE"
pubSubRoot="NONE"
pubStandbyHostIP="NONE"
excludeList="NONE"
includeList="NONE"
workDir="NONE"
repairBroken=0
fullReset=0
initialSetup=0
listUsed=0
pubPGversion=0
subPGversion=0
pgDumpVersion=0
schemaOwner="postgres"


function print_usage {
    echo
    echo "Usage:  $0 [options]"
    echo
    echo "Options:"
    echo "--help   print usage"
    echo "-h   [publisher host IP] [Required]"
    echo "-s   [schema name] [Required]"
    echo "-o   [schema Owner] [optonal, defaults to postgres]"
    echo "-d   [publisher dbname] [Required]"
    echo "-D   [subscriber dbname] [Required]"
    echo "-n   [publication/subscriber root name, without _pub or _sub] [Required]"
    echo "-w   [workDir for temp files] [Required]"
    echo "     Warning: workDir will be truncated before each run"
    echo "-A   [Action, specify one of the following:] [Required]   "
    echo "     SETUP        [Perform initial setup of pg2pg replication] "
	echo "                    will assume all tables in the provided schema unless -I or -E is specified"
	echo
    echo "     RESET        [Perform a reset: truncate and reset of tables] "
	echo "                    will assume all tables in the provided schema unless -I or -E is specified"
	echo
    echo "     DDL        [Perform a DDL repar: fix DDL diffs for tables broken due to DDL changes]"
	echo "                    will assume all tables currently in the existing publication unless -I or -E is specified"
	echo
    echo "     DROP        [Perform a table drop of all specified tables, requires include list]"
	echo "                    requires that a -I (include list) is specified, and that the tables in the include list are currently in the publication"
	echo
    echo "     ADD-SYNC     [Perform a table add of all specified tables, and forces an initial sync of the added tables - requires include list]"
	echo "                    requires that a -I (include list) is specified, and only tables in the list that are NOT currently in the publication will be added"
	echo
    echo "     ADD-NOSYNC   [Perform a table add of all specified tables, and prevents an initial sync of the added tables - requires include list]"
	echo "                    requires that a -I (include list) is specified, and only tables in the list that are NOT currently in the publication will be added"
	echo
	echo
    echo "-E   [Exclude table list file] {Optional}"
    echo "-I   [Include table list file] {Optional}"
	echo "    Note: -E and -I are mutually exclusive, provide only one, or if neither"
	echo "           option is provided then all tables in the passed in schemaname will be used"
	echo "    Exclude and Include list must be a list of tables in schemaname.tablename format"
	echo "           with one table per line and no commas or semicolons at the end of the line"
	echo
    echo "-H   [publisher standby host IP] {Optional}"
	echo "     only valid with action = SETUP"
    echo
	echo
	echo "This script is designed to be run on the subscriber"
	echo " it will create / alter the publication on the publisher"
	echo " it will also create / alter the local subscription "
	echo "   on the subscriber (the local host)"
	echo
	echo "The publication will contain all tables in the specified schema"
	echo "   unless an Exclude List or Include List is specified"
	echo " Note: all tables that have any partitions will be skipped"
	echo " since we only want to replicate partitions and stand alone tables"
	echo
	echo "Passing in the optional 'publisher standby host IP' "
	echo "   will force the subscriber to use the source standby IP as its publisher"
	echo "   otherwise it will point the subscriber to the source host IP (master) as its publisher"
	echo
}

function log_message {
	echo "$1"
	echo "$1" >> $logFile
}

function error_check {

	abortFlag=$1

	

	cat ${psqlOUTfile} >> $logFile
	log_message
	errCount=0
	errCountSTR=$( cat ${psqlOUTfile} | grep ERROR: |grep -viE 'role|function|trigger'| wc -l )
	set - $errCountSTR
	errCount=$1

	if [ $errCount -gt 0 ]
	then
		if [ $abortFlag -eq 1 ]
		then
			log_message "ERROR's found"
			log_message "Aborting run"
			echo "ERROR: $(cat ${psqlOUTfile} | grep ERROR: |grep -viE 'role|function|trigger')"
			exit
		fi
	fi
}


function set_tablist {

	log_message
	log_message "--| set_tablist"


	#--| Build the table list
	tabList=""

	#--| if ${listUsed} -eq 1 [includeList specified]
	if [ ${listUsed} -eq 1 ]
	then
		log_message "includeList specified [$includeList]"

		# leading spaces
		log_message "Eliminate leading spaces from include list lines"
		cat ${includeList} | sed "s/^[[:blank:]]*//" > ${includeList}.noleading
		mv -f ${includeList}.noleading ${includeList}

		# trailing spaces
		log_message "Eliminate trailing spaces from include list lines"
		cat ${includeList} | sed "s/[[:blank:]]*$//" > ${includeList}.notrailing
		mv -f ${includeList}.notrailing ${includeList}

		# blank lines
		log_message "Eliminate blank lines from include list"
		cat ${includeList} | grep -v "^$" > ${includeList}.noblanks
		mv -f ${includeList}.noblanks ${includeList}

		tabList=$includeList
	fi

	#--| if ${listUsed} -eq 2 [excludeList specified]
	if [ ${listUsed} -eq 2 ]
	then
		log_message "excludeList specified [$excludeList]"

		# leading spaces
		log_message "Eliminate leading spaces from exclude list lines"
		cat ${excludeList} | sed "s/^[[:blank:]]*//" > ${excludeList}.noleading
		mv -f ${excludeList}.noleading ${excludeList}

		# trailing spaces
		log_message "Eliminate trailing spaces from exclude list lines"
		cat ${excludeList} | sed "s/[[:blank:]]*$//" > ${excludeList}.notrailing
		mv -f ${excludeList}.notrailing ${excludeList}

		# blank lines
		log_message "Eliminate blank lines from exclude list"
		cat ${excludeList} | grep -v "^$" > ${excludeList}.noblanks
		mv -f ${excludeList}.noblanks ${excludeList}

		dropSQL="DROP TABLE IF EXISTS public.exclude_pg_list" 
		log_message "DROP TABLE IF EXISTS public.exclude_pg_list"
		echo "$dropSQL" | psql -h ${pubHostIP} ${publisherDB} > ${psqlOUTfile} 2>&1
		error_check 1

		crtSQL="CREATE TABLE public.exclude_pg_list (tablename varchar)" 
		log_message "CREATE TABLE public.exclude_pg_list"
		echo "$crtSQL" | psql -h ${pubHostIP} ${publisherDB} > ${psqlOUTfile} 2>&1
		error_check 1


		copySQL="\copy public.exclude_pg_list FROM '${excludeList}'"
		log_message "COPY data into public.exclude_pg_list"
		echo "$copySQL" | psql -h ${pubHostIP} ${publisherDB} > ${psqlOUTfile} 2>&1
		error_check 1

		listSQL="SELECT schemaname || '.' || tablename
					FROM pg_tables
					WHERE schemaname = '${schemaName}'
					AND schemaname || '.' || tablename NOT IN
					(SELECT tablename from public.exclude_pg_list)"

		tabList=${workDir}/tablist.txt
		log_message "Execute SELECT to get tablist minus the exclude list"
		echo "$listSQL" | psql -t -h ${pubHostIP} ${publisherDB} > ${tabList} 2> ${psqlOUTfile} 
		error_check 1

		dropSQL="DROP TABLE IF EXISTS public.exclude_pg_list" 
		log_message="DROP TABLE IF EXISTS public.exclude_pg_list" 
		echo "$dropSQL" | psql -h ${pubHostIP} ${publisherDB} > ${psqlOUTfile} 2>&1
		error_check 1

	fi

	#--| if ${listUsed} -eq 0 [no includeList or excludeList specified]
	if [ ${listUsed} -eq 0 ]
	then
		echo
		listSQL="SELECT schemaname || '.' || tablename
					FROM pg_tables
					WHERE schemaname = '${schemaName}'"

		tabList=${workDir}/tablist.txt
		log_message "Generate tablist (no include or exclude list specified"
		echo "$listSQL" | psql -t -h ${pubHostIP} ${publisherDB} > ${tabList} 2> ${psqlOUTfile}
		error_check 1
	fi
	log_message
	log_message "Tablist assigned"
	log_message "tabList   [$tabList]"

}




function print_variables {
	#--| Print Variables
	echo
	echo "pubHostIP          [$pubHostIP]"
	echo "schemaName         [$schemaName]"
	echo "publisherDB        [$publisherDB]"
	echo "subscriberDB       [$subscriberDB]"
	echo "pubSubRoot         [$pubSubRoot]"
	echo "pubStandbyHostIP   [$pubStandbyHostIP]"
	echo "excludeList        [$excludeList]"
	echo "includeList        [$includeList]"
	echo "actionTAG          [$actionTAG]"
	echo "listUsed           [$listUsed]"
	echo "workDir            [$workDir]"
	echo
	echo
}


function setup_work_dir_and_log {

	if [ "$workDir" == "/tmp" ]
	then
		echo
		echo "ERROR: -w  [workDir] cannot be /tmp since it needs to be truncated first"
		echo
		print_usage
		exit
	fi

	if [ "$workDir" == "NONE" ]
	then
		echo
		echo "ERROR: -w  [workDir] is required"
		echo
		print_usage
		exit
	else
		if [ -d "$workDir" ]
		then
			echo
			echo "Truncating workDir [$workDir]"
			echo "[rm -fr ${workDir}/*]"
			rm -fr ${workDir}/*
			if [ $? -ne 0 ]
			then
				echo
				echo "ERROR: workDir [$workDir] truncate failed"
				echo "Aborting run"
				echo
				exit
			fi
		else
			echo
			echo "Creating workDir [$workDir]"
			mkdir ${workDir}

			if [ ! -d "$workDir" ]
			then
				echo
				echo "ERROR: could not create workDir [$workDir]"
				echo "Aborting run"
				echo
				print_usage
				exit
			else
				echo
				echo "Success, created workDir [$workDir]"
			fi
		fi
	fi


	logFN=$( basename $0 .sh )
	logFile=${workDir}/${logFN}.log
	echo
	echo "logFile [$logFile]"
	log_message
	startDT=$( date )
	log_message "--| $0 run started at $startDT"

	psqlOUTfile=${workDir}/psql.output
}

function verify_inputs {

	if [ "$1" == "--help" ]
	then
		echo
		print_usage
		exit
	fi


	if [ "$pubHostIP" == "NONE" ]
	then
		echo
		echo "ERROR: -h  [publisher host IP] is required"
		echo
		print_usage
		exit
	fi

	if [ "$schemaName" == "NONE" ]
	then
		echo
		echo "ERROR: -s [schema name] is required"
		echo
		print_usage
		exit
	fi

	if [ "$publisherDB" == "NONE" ]
	then
		echo
		echo "ERROR: -d [publisher dbname] is required"
		echo
		print_usage
		exit
	fi

	if [ "$subscriberDB" == "NONE" ]
	then
		echo
		echo "ERROR: -D [subscriber dbname] is required"
		echo
		print_usage
		exit
	fi

	if [ "$pubSubRoot" == "NONE" ]
	then
		echo
		echo "ERROR: -n [publication/subscriber root name, without _pub or _sub] is required"
		echo
		print_usage
		exit
	fi

	if [ "$excludeList" != "NONE" -a "$includeList" != "NONE" ]
	then
		echo
		echo "ERROR: -I include list and -E exclude list are mutually exclusive, only one can be specified"
		echo
		print_usage
		exit
	fi

	if [ "$pubStandbyHostIP" != "NONE"  ]
	then
		if [ "$actionTAG" != "SETUP"  -a "$actionTAG" != "RESET" ]
		then
			echo
			echo "ERROR: publisher standby host IP [-H] is only valid if actionTag [-A] = SETUP or RESET"
			echo
			print_usage
			exit
		fi
	fi

	if [ "$pubStandbyHostIP" == "NONE" -a  "$actionTAG" == "SETUP" ]
	then
		pubStandbyHostIP=$pubHostIP
	fi

	if [ "$pubStandbyHostIP" == "NONE" -a  "$actionTAG" == "RESET" ]
	then
		pubStandbyHostIP=$pubHostIP
	fi

	if [ "$includeList" != "NONE" ]
	then
		listUsed=1
	fi

	if [ "$excludeList" != "NONE" ]
	then
		listUsed=2
	fi

	case $actionTAG in
		SETUP)
			;;

		RESET)
			;;

		DDL)
			;;

		DROP)
			;;

		ADD-SYNC)
			if [ $listUsed -ne 1 ]
			then
				echo
				echo "ERROR: ADD-SYNC action requires an include list (-I)"
				echo
				echo
				print_usage
				exit
			fi
			;;

		ADD-NOSYNC)
			if [ $listUsed -ne 1 ]
			then
				echo
				echo "ERROR: ADD-SYNC action requires an include list (-I)"
				echo
				echo
				print_usage
				exit
			fi
			;;

		*)
			echo
			echo "ERROR: -A [actionTAG] must be one of the following:"
			echo "     SETUP        [Perform initial setup of pg2pg replication] "
			echo "     RESET        [Perform a reset: truncate and reset of tables] "
			echo "     DDL          [Perform a DDL repar: fix DDL diffs for tables broken due to DDL changes]"
			echo "     DROP         [Perform a table drop of all specified tables, requires include list]"
			echo "     ADD-SYNC     [Perform a table add of all specified tables, and forces an initial sync of the added tables - requires include list]"
			echo "     ADD-NOSYNC   [Perform a table add of all specified tables, and prevents an initial sync of the added tables - requires include list]"
			echo
			echo
			echo
			print_usage
			exit
			;;

	esac

}

function unimplemented_feature_check {

			if [ "$actionTAG" == "DDL" ]
			then
				echo
				echo
				echo
				echo
				echo "actionTAG = DDL has not yet been implemented"
				echo
				exit
			fi

			if [ "$actionTAG" == "DROP" ]
			then
				echo
				echo
				echo
				echo
				echo "actionTAG = DROP has not yet been implemented"
				echo
				exit
			fi

			if [ "$actionTAG" == "ADD-SYNC" ]
			then
				echo
				echo
				echo
				echo
				echo "actionTAG = ADD-SYNC has not yet been implemented"
				echo
				exit
			fi

			if [ "$actionTAG" == "ADD-NOSYNC" ]
			then
				echo
				echo
				echo
				echo
				echo "actionTAG = ADD-NOSYNC has not yet been implemented"
				echo
				exit
			fi
}


function set_pgdump_path {

	log_message
	log_message "--| set_pgdump_path"

	# get local pg_dump version
	log_message "get local pg_dump version" 
	pgDumpVersionSTR2=$( pg_dump -V )
	pgDumpVersionSTR=$( echo "$pgDumpVersionSTR2" | sed "s/\./ /g" )
	set - $pgDumpVersionSTR
	pgDumpVersion=$3
	log_message "pgDumpVersion [$pgDumpVersion]"
	

	# get pub version
	log_message "get publication db version" 
	pubVersionSTR2=$( psql -h ${pubHostIP} -tc "select version()" )
	pubVersionSTR=$( echo "$pubVersionSTR2" | sed "s/\./ /g" )
	set - $pubVersionSTR
	pubPGversion=$2
	log_message "pubPGversion [$pubPGversion]"

	# get local / sub version
	log_message "get local / subscriber db version"
	subVersionSTR2=$( psql -tc "select version()" )
	subVersionSTR=$( echo "$subVersionSTR2" | sed "s/\./ /g" )
	set - $subVersionSTR
	subPGversion=$2
	log_message "subPGversion [$subPGversion]"

	if [ $pubPGversion -gt $pgDumpVersion ]
	then
		if [ ! -f  "/usr/pgsql-${pubPGversion}/bin/pg_dump" ]
		then
			log_message
			log_message "ERROR: publisher pg version = [$pubPGversion], and sub pg version = [$subPGversion]"
			log_message "   which means the right pg_dump version to use is in /usr/pgsql-${pubPGversion}/bin"
			log_message "   however /usr/pgsql-${pubPGversion}/bin does not exist, so obviously "
			log_message "   PostgreSQL Version [$pubPGversion] binaries are not installed here, aborting"
			log_message "   Install PostgreSQL Version ${pubPGversion} on the subscriber (this box) and re-try"
			log_message
			exit
		fi

		PGDUMP=/usr/pgsql-${pubPGversion}/bin/pg_dump
	else 
		PGDUMP=pg_dump
	fi

	log_message "PGDUMP version set"
	log_message "PGDUMP [$PGDUMP]"
}


function drop_pub_and_sub {
	
	log_message
	log_message "--| drop_pub_and_sub"

	pubName=${pubSubRoot}_pub
	subName=${pubSubRoot}_sub

	log_message "pubName     [$pubName]"
	log_message "subName     [$subName]"


	log_message "DROP SUBSCRIPTION IF EXISTS ${subName}" 
	echo "DROP SUBSCRIPTION IF EXISTS ${subName}" | psql ${subscriberDB} > ${psqlOUTfile} 2>&1
	error_check 1

	log_message "DROP PUBLICATION IF EXISTS ${pubName}" 
	echo "DROP PUBLICATION IF EXISTS ${pubName}" | psql -h ${pubHostIP} ${publisherDB} > ${psqlOUTfile} 2>&1
	error_check 1

}


function gen_pub_and_sub_commands {
	
	log_message
	log_message "--| gen_pub_and_sub_commands"

	if [ "${pubStandbyHostIP}" == "NONE" ]
	then
		pubStandbyHostIP=${pubHostIP}
	fi

	pubName=${pubSubRoot}_pub
	subName=${pubSubRoot}_sub
	genPubFile=${workDir}/${pubName}.sql
	genSubFile=${workDir}/${subName}.sql
	finalTablist=${workDir}/finalTablist.txt
	> ${finalTablist}

	log_message "pubName     [$pubName]"
	log_message "subName     [$subName]"
	log_message "genPubFile  [$genPubFile]"

	log_message 
	log_message "Loop through tabList and create publication"
	echo "CREATE PUBLICATION ${pubName} FOR TABLE" > $genPubFile
	pubCntr=1
	for I in $( cat ${tabList} )
	do
		tabParts=$( echo $I | sed "s/\./ /" )
		set - $tabParts
		schName="$1"
		tabName="$2"

		# unlogged table check
		unloggedCheckSQL="select relpersistence from pg_class 
							where relname = '${tabName}' 
							and relnamespace = (select oid from pg_namespace where nspname = '${schName}');
							"

		tabRelpersistence=""
		unloggedCheckSTR=$( echo "$unloggedCheckSQL" | psql -t -h $pubHostIP $publisherDB )
		set - $unloggedCheckSTR
		tabRelpersistence="$1"

		if [ "$tabRelpersistence" == "u" ]
		then
			log_message "Skipping Unlogged Table [$I]"
			continue
		fi

		partCountSQL="SELECT count(*)
			FROM pg_inherits
			JOIN pg_class parent            ON pg_inherits.inhparent = parent.oid
			JOIN pg_class child             ON pg_inherits.inhrelid   = child.oid
			JOIN pg_namespace nmsp_parent   ON nmsp_parent.oid  = parent.relnamespace
			JOIN pg_namespace nmsp_child    ON nmsp_child.oid   = child.relnamespace
			WHERE parent.relname='${tabName}' AND nmsp_child.nspname = '${schName}'
			"

		patCountSTR=$( echo "$partCountSQL" | psql -t -h $pubHostIP $publisherDB )
		set - $patCountSTR
		partCount=$1

		if [ $partCount -gt 0 ]
		then
			echo "Skippinig partition parent [$I]"
			echo "Skippinig partition parent [$I]" >> $logFile
			continue
		else
			tabTypeSQL="SELECT c.relpersistence FROM pg_catalog.pg_class c 
						LEFT JOIN pg_catalog.pg_namespace n 
						 ON n.oid = c.relnamespace 
						 "

			log_message "Adding [$I] to PUBLICATION and to finalTablist [$finalTablist]"
			if [ $pubCntr -eq 1 ]
			then
				echo "$I" >> $genPubFile
			else
				echo ", ${I}" >> $genPubFile
			fi
			echo "$I" >> ${finalTablist}
			
		fi

		pubCntr=$(( $pubCntr + 1 ))

	done

	echo ";" >> $genPubFile
	log_message
	log_message "Generate CREATE SUBSCRIPTION command"
	subSQL="CREATE SUBSCRIPTION ${subName} CONNECTION 'host=${pubStandbyHostIP} dbname=${publisherDB}' PUBLICATION ${pubName}"
	echo "$subSQL" > ${genSubFile}

	ftCountSTR=$( cat ${finalTablist} | grep -v "^$" | wc -l )
	set - $ftCountSTR
	ftCount=$1

	if [ $ftCount -eq 0 ]
	then
		log_message
		log_message
		log_message "ERROR: once the unlogged tables and partition tables were eliminated from the list there are no remaining tables in the list"
		log_message "Evaluate table list and retry, aborting"
		log_message
		log_message
		exit
	fi

	
}


function logical_replication_check {

	log_message
	log_message "--| logical_replication_check"

	pubName=${pubSubRoot}_pub
	subName=${pubSubRoot}_sub

	log_message "pubName     [$pubName]"
	log_message "subName     [$subName]"

	subSQL="SELECT count(*) from pg_subscription where subname = '${subName}'"
	subCountSTR=$( echo "$subSQL" | psql -t ${subscriberDB} )
	set - $subCountSTR
	subCount=$1

	if [ $subCount -ne 0 ]
	then
		log_message
		log_message "ERROR: subscription [$subName] already exists, use RESET instead of SETUP to drop and re-set logical replication"
		log_message
		exit
	fi

	#pubSQL="SELECT count(*) from pg_publication where pubname = '${pubName}'"
	#pubCountSTR=$( echo "$pubSQL" | psql -h ${pubHostIP} ${publisherDB} )
	pubCount=$(psql -h ${pubHostIP} -d ${publisherDB} -Atqc "SELECT count(*) FROM pg_publication WHERE pubname='${pubName}'")
	set - $pubCountSTR
	pubCount=$1

	if [ $pubCount -ne 0 ]
	then
		log_message
		log_message "ERROR: publication [$pubName] already exists, use RESET instead of SETUP to drop and re-set logical replication"
		log_message
		exit
	fi
}



function logical_replication_missing_check {

	log_message
	log_message "--| logical_replication_missing_check"

	pubName=${pubSubRoot}_pub
	subName=${pubSubRoot}_sub

	log_message "pubName     [$pubName]"
	log_message "subName     [$subName]"

	subSQL="SELECT count(*) from pg_subscription where subname = '${subName}'"
	subCountSTR=$( echo "$subSQL" | psql -t ${subscriberDB} )
	set - $subCountSTR
	subCount=$1

	if [ $subCount -eq 0 ]
	then
		log_message
		log_message "ERROR: subscription [$subName] not found, use SETUP instead of RESET to setup logical replication"
		log_message
		exit
	fi

	pubSQL="SELECT count(*) from pg_publication where pubname = '${pubName}'"
	pubCountSTR=$( echo "$pubSQL" | psql -h ${pubHostIP} ${publisherDB} -At )
	set - $pubCountSTR
	pubCount=$1

	if [ $pubCount -eq 0 ]
	then
		log_message
		log_message "ERROR: publication [$pubName] not found, use SETUP instead of RESET to setup logical replication"
		log_message
		exit
	fi
}


function backup_dependant_objects {

	log_message
	log_message "--| backup_dependant_objects"

	depObjList=${workDir}/depObjList.txt
	> ${depObjList}

	postDataDump=${workDir}/postDataDump.sql
	> ${postDataDump}

	depObjDump=${workDir}/depObjDump.sql
	> ${depObjDump}


	log_message "Check if schema [${schemaName}] already exists"
	schemaCheckSQL="select count(*) from pg_namespace where nspname = '${schemaName}'"
	schemaCheckSTR=$( echo "$schemaCheckSQL" | psql -t ${subscriberDB} )
	set - $schemaCheckSTR
	schemaCount=$1


	if [ $schemaCount -gt 0 ]
	then
		log_message
		log_message "Schema [${schemaName}] exists, backing up triggers, indexes, etc"

		for I in $( cat ${tabList} )
		do
			tabParts=$( echo $I | sed "s/\./ /" )
			set - $tabParts
			schName="$1"
			tabName="$2"
			log_message "[$schName] [$tabName]"
			checkTabSQL="SELECT count(*) FROM pg_tables WHERE schemaname = '${schName}' AND tablename = '${tabName}'"
			checkTabSTR=$( echo "$checkTabSQL" | psql -t ${subscriberDB} )
			set - $checkTabSTR
			tabCount=$1

			if [ $tabCount -eq 0 ]
			then
				log_message "Skipping table $I that does not exist in the subscriberDB"
			else

				depObjectsSQL="SELECT DISTINCT
							dependent_ns.nspname || '.' ||  dependent_view.relname as dependent_view 
							FROM pg_depend 
							JOIN pg_rewrite ON pg_depend.objid = pg_rewrite.oid 
							JOIN pg_class as dependent_view ON pg_rewrite.ev_class = dependent_view.oid 
							JOIN pg_class as source_table ON pg_depend.refobjid = source_table.oid 
							JOIN pg_attribute ON pg_depend.refobjid = pg_attribute.attrelid 
								AND pg_depend.refobjsubid = pg_attribute.attnum 
								JOIN pg_namespace dependent_ns ON dependent_ns.oid = dependent_view.relnamespace
								JOIN pg_namespace source_ns ON source_ns.oid = source_table.relnamespace
								WHERE 
								source_ns.nspname = '${schName}'
								AND source_table.relname = '${tabName}'
								"


				echo "$depObjectsSQL" | psql -t ${subscriberDB} | grep -v "^$" >> ${depObjList}
			fi
		done

		# backup all dependant objects
		log_message "backup all dependant objects"

		for I in $( cat ${depObjList} )
		do
			log_message "${PGDUMP} -s --table=${I} ${subscriberDB} >> ${depObjDump}"
			${PGDUMP} -s --table=${I} ${subscriberDB} >> ${depObjDump}
		done

		# dump current schema DDL to get all triggers, indexes, and other tables 
		log_message "${PGDUMP} -s --schema=${schemaName} ${subscriberDB} >> ${postDataDump}"
		${PGDUMP} -s --schema=${schemaName} ${subscriberDB} >> ${postDataDump}


	fi
}



function drop_and_recreate_replicated_objects {

	log_message
	log_message "--| drop_and_recreate_replicated_objects"

	srcDDLdump=${workDir}/srcDDLdump.sql
	> ${srcDDLdump}

	attachPartFile=${workDir}/srcAttachPartFile.sql
	> ${attachPartFile}

	dropObjects=${workDir}/dropObjects.sql
	> ${dropObjects}

	log_message "Create drop objects file"
	for I in $( cat ${tabList} )
	do
		tabParts=$( echo $I | sed "s/\./ /" )
		set - $tabParts
			${PGDUMP} -h ${pubHostIP} -s --table=${I} ${publisherDB} >> ${srcDDLdump}
			echo "DROP TABLE IF EXISTS ${I} CASCADE;" >> ${dropObjects}
	done

	log_message "Parse ATTACH PARTITION Statements from the source DDL backup [$srcDDLdump]"
	cp ${srcDDLdump} ${srcDDLdump}.tmp
	cat ${srcDDLdump}.tmp | grep -v "ATTACH PARTITION" > ${srcDDLdump}
	cat ${srcDDLdump}.tmp | grep -B 2 -A 2  "ATTACH PARTITION" > ${attachPartFile}

	# check for schema owner 
	log_message "Check for local role of schema owner"
	roleCheckSQL="SELECT count(*) FROM pg_roles WHERE rolname = '${schemaOwner}'"
	roleCheckSTR=$( echo "$roleCheckSQL" | psql -t ${subscriberDB} )
	set - $roleCheckSTR
	roleCheck=$1

	if [ $roleCheck -lt 1 ]
	then
		log_message
		log_message "ERROR: passed in schemaOwner [${schemaOwner}] does not exist, aborting run"
		log_message
		exit
	fi

	# create schema if needed and set ownership
	log_message
	log_message "CREATE SCHEMA IF NOT EXISTS ${schemaName}" 
	echo "CREATE SCHEMA IF NOT EXISTS ${schemaName}" | psql ${subscriberDB} > ${psqlOUTfile} 2>&1
	error_check 1
	log_message "ALTER SCHEMA ${schemaName} OWNER TO ${schemaOwner}" 
	echo "ALTER SCHEMA ${schemaName} OWNER TO ${schemaOwner}" | psql ${subscriberDB}

	# drop the existing objects
	log_message
	log_message "drop existing objects"
	log_message "[psql -f ${dropObjects} ${subscriberDB}]"
	psql -f ${dropObjects} ${subscriberDB} > ${psqlOUTfile} 2>&1
	error_check 1

	# Create the replication objects
	log_message
	log_message "Create the replication objects"
	log_message "[psql -f ${srcDDLdump} ${subscriberDB}]"
	# Remove FOREIGN KEY constraints to avoid issues during replication
	log_message "Removing FOREIGN KEY constraints from ${srcDDLdump}"
	awk '
	    /ALTER TABLE/ {
	        block = $0;
	        while (getline > 0) {
	            block = block "\n" $0;
	            if ($0 ~ /;/) break;
	        }
	        if (block !~ /FOREIGN KEY/) print block;
	        next;
	    }
	    {
	        gsub(/ REFERENCES [^),]*/, "", $0);
	        print $0;
	    }
	' ${srcDDLdump} > ${srcDDLdump}.tmp && mv ${srcDDLdump}.tmp ${srcDDLdump}

	psql -f ${srcDDLdump} ${subscriberDB} > ${psqlOUTfile} 2>&1
	error_check 1

	# Execute any needed ATTACH PARTITION statements
	log_message
	log_message "Execute any needed ATTACH PARTITION statements"
	log_message "[psql -f ${attachPartFile} ${subscriberDB}]"
	psql -f ${attachPartFile} ${subscriberDB} > ${psqlOUTfile} 2>&1
	error_check 0


	# Create/Re-Create dependant objects
	log_message
	log_message "Create/Re-Create dependant objects"
	log_message "[psql -f ${depObjDump} ${subscriberDB}]"
	psql -f ${depObjDump} ${subscriberDB} > ${psqlOUTfile} 2>&1
	error_check 0


	# Execute any triggers, Indexes, etc that were in place before the run started
	log_message
	log_message "Execute any triggers, Indexes, etc that were in place before the run started"
	log_message "[psql -f ${postDataDump} ${subscriberDB}]"
	psql -f ${postDataDump} ${subscriberDB} > ${psqlOUTfile} 2>&1
	error_check 0
}




function create_publication {

	log_message
	log_message "--| create_publication"

	# Create publication
	log_message "[psql -h ${pubHostIP} -f ${genPubFile} ${publisherDB}]"
	psql -h ${pubHostIP} -f ${genPubFile} ${publisherDB} > ${psqlOUTfile} 2>&1
	error_check 1
}


function create_subscription {
	# Create subscription
	log_message "[psql -f ${genSubFile} ${subscriberDB}]"
	psql -f ${genSubFile} ${subscriberDB} > ${psqlOUTfile} 2>&1
	error_check 1
}


function drop_tables_from_pub {

	log_message
	log_message "--| drop_tables_from_pub"

	pubName=${pubSubRoot}_pub
	subName=${pubSubRoot}_sub



	log_message "drop tabs from publication"
	log_message "using finalTablist [$finalTablist] for the list, which eliminates non logged and partitioned tables"
	for I in $( cat ${finalTablist} )
	do
		log_message "ALTER PUBLICATION ${pubName} DROP TABLE ${I}"
		echo "ALTER PUBLICATION ${pubName} DROP TABLE ${I}" | psql -h ${pubHostIP} ${publisherDB} > ${psqlOUTfile} 2>&1
		error_check 1
	done


	log_message "ALTER SUBSCRIPTION ${subName} REFRESH PUBLICATION"
	echo "ALTER SUBSCRIPTION ${subName} REFRESH PUBLICATION" | psql ${subscriberDB} > ${psqlOUTfile} 2>&1
	error_check 1
}


function add_tables_to_pub {

	log_message
	log_message "--| add_tables_to_pub"

	pubName=${pubSubRoot}_pub
	subName=${pubSubRoot}_sub



	log_message "add tabs to publication"
	log_message "using finalTablist [$finalTablist] for the list, which eliminates non logged and partitioned tables"
	for I in $( cat ${finalTablist} )
	do
		log_message "ALTER PUBLICATION ${pubName} ADD TABLE ${I}"
		echo "ALTER PUBLICATION ${pubName} ADD TABLE ${I}" | psql -h ${pubHostIP} ${publisherDB} > ${psqlOUTfile} 2>&1
		error_check 1
	done


	log_message "ALTER SUBSCRIPTION ${subName} REFRESH PUBLICATION"
	echo "ALTER SUBSCRIPTION ${subName} REFRESH PUBLICATION" | psql ${subscriberDB} > ${psqlOUTfile} 2>&1
	error_check 1
}



#-- Main
if [ $# -eq 0 ]
then
	print_usage
	exit
fi

if [ "$1" == "--help" ]
then
	print_usage
	exit
fi

while getopts ":h:w:s:o:d:D:n:E:I:A:H:" opt;
do
    case ${opt} in
		h)
			pubHostIP="${OPTARG}"
			;;

		w)
			workDir="${OPTARG}"
			;;

		s)
			schemaName="${OPTARG}"
			;;

		o)
			schemaOwner="${OPTARG}"
			;;

		d)
			publisherDB="${OPTARG}"
			;;

		D)
			subscriberDB="${OPTARG}"
			;;

		n)
			pubSubRoot="${OPTARG}"
			;;

		E)
			excludeList="${OPTARG}"
			;;

		I)
			includeList="${OPTARG}"
			;;

		A)
			actionTAG="${OPTARG^^}"
			;;

		H)
			pubStandbyHostIP="${OPTARG}"
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

unimplemented_feature_check

print_variables

setup_work_dir_and_log

verify_inputs

set_tablist

set_pgdump_path


if [ "$actionTAG" == "SETUP" ]
then

	gen_pub_and_sub_commands

	logical_replication_check

	backup_dependant_objects

	drop_and_recreate_replicated_objects

	create_publication

	create_subscription
fi



if [ "$actionTAG" == "RESET" ]
then
	if [ $listUsed -eq 1 ]
	then
		backup_dependant_objects

		gen_pub_and_sub_commands

		drop_tables_from_pub

		drop_and_recreate_replicated_objects

		add_tables_to_pub
	else
		logical_replication_missing_check

		backup_dependant_objects

		gen_pub_and_sub_commands

		drop_pub_and_sub

		drop_and_recreate_replicated_objects

		create_publication

		create_subscription
	fi
fi



