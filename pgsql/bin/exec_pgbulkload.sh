#!/bin/bash
#
# Ansible managed
#
#-- Global PATHs
# scriptBASE=/var/lib/pgsql/bulkload
RM=/usr/bin/rm
AWS=/usr/local/bin/aws
CAT=/usr/bin/cat
UNZIP=/usr/bin/unzip
BULKLOAD=/usr/pgsql-14/bin/pg_bulkload
OLDIFS="$IFS"

function print_usage {
	echo
	echo "Usage: $0 "
	echo "     -e endpointURL "
	echo "     -p endpointPort "
	echo "     -u sourceS3URL "
	echo "     -n s3ProfileName "
	echo "     -w workDir "
	echo "     -d dbName "
	echo "     -s dbSchema "
	echo "     -l bulkloadLogdir "
	echo "     -a actionTAG "
	echo "     -f processFile "
	echo
	echo "     -h = print help"
	echo
}

function parse_cfg {
	#while getopts ":e:p:u:n:w:s:l:a:f:h" optFlag
	while getopts ":e:" optFlag
	do
		case "${optFlag}" in

			"h")
				print_usage
				exit
				;;

			"e")
				echo "e"
				exho "[$OPTARG]"
				endpointURL="$OPTARG"
				;;

			"p")
				endpointPort="$OPTARG"
				;;

			"u")
				sourceS3URL="$OPTARG"
				;;

			"n")
				s3ProfileName="$OPTARG"
				;;

			"w")
				workDir="$OPTARG"
				;;

			"d")
				dbName="$OPTARG"
				;;

			"s")
				dbSchema="$OPTARG"
				;;


			"l")
				bulkloadLogdir="$OPTARG"
				;;


			"a")
				actionTAG="$OPTARG"
				;;


			"f")
				processFile="$OPTARG"
				;;

		esac
	done

dbHost="localhost"

}

#if [ $# -lt 18 ]
#then
	#print_usage
	#exit
#fi

while getopts ":e:p:u:n:w:d:s:l:a:f:h" optFlag
do
	case "${optFlag}" in

		"h")
			print_usage
			exit
			;;

		"e")
			endpointURL="$OPTARG"
			;;

		"p")
			endpointPort="$OPTARG"
			;;

		"u")
			sourceS3URL="$OPTARG"
			;;

		"n")
			s3ProfileName="$OPTARG"
			;;

		"w")
			workDir="$OPTARG"
			;;

		"d")
			dbName="$OPTARG"
			;;

		"s")
			dbSchema="$OPTARG"
			;;

		"l")
			bulkloadLogdir="$OPTARG"
			;;

		"a")
			actionTAG="$OPTARG"
			;;

		"f")
			processFile="$OPTARG"
			;;

	esac
done

dbHost="localhost"


if [ $actionTAG -ne 0 -a $actionTAG -ne 1 -a $actionTAG -ne 2 ]
then
	echo
	echo "ERROR: invalid value for action [$actionTAG], aborting"
	echo
	exit
fi


#-- Show run values
echo
echo "Executing $0 with the following values:"
echo "endpointURL     [$endpointURL]"
echo "endpointPort    [$endpointPort]"
echo "sourceS3URL     [$sourceS3URL]"
echo "s3ProfileName   [$s3ProfileName]"
echo "workDir         [$workDir]"
echo "dbHost          [$dbHost]"
echo "dbName          [$dbName]"
echo "dbSchema        [$dbSchema]"
echo "bulkloadLogdir  [$bulkloadLogdir]"
echo "actionTAG       [$actionTAG]"
if [ $actionTAG -eq 2 ]
then
	echo "processFile     [$processFile]"
fi
echo


loopIND=0
if [ $actionTAG -eq 1 ]
then
	loopIND=1
fi

for I in "$workDir" "$bulkloadLogdir"
do
	echo "$I" | grep "^\."
	if [ $? -eq 0 ]
	then
		echo "ERROR: relative path found [$I], all paths must be full paths, aborting"
		exit
	fi
done

# verify that $sourceS3URL ends with a slash
echo "$sourceS3URL" | grep "/$" > /dev/null
if [ $? -ne 0 ]
then
	echo
	echo "ERROR: source_s3_url [$sourceS3URL ] must end with a slash, aborting"
	echo
	exit
fi

#-- Validate workDir directory
echo "Validating workDir [$workDir]"
if [ ! -d "$workDir" ]
then
	echo "ERROR: workDir [$workDir] does not exist or is not a directory, aborting"
	exit
else
	echo "Done"
	echo
fi

#-- cleanup / truncate workDir
echo "Truncate workDir [$workDir]"
${RM} -f  ${workDir}/*
if [ $? -ne 0 ]
then
	echo "ERROR: Truncate of workDir [$workDir] failed, aborting"
	exit
else
	echo "Done"
	echo
fi


#-- Validate bulkloadLogdir directory
echo "Validating bulkloadLogdir [$bulkloadLogdir]"
if [ ! -d "$bulkloadLogdir" ]
then
	echo "ERROR: bulkloadLogdir [$bulkloadLogdir] does not exist or is not a directory, aborting"
	exit

else
	echo "Done"
	echo
fi

#-- cleanup / truncate bulkloadLogdir
echo "Truncate log dir [$bulkloadLogdir]"
${RM} -fr  ${bulkloadLogdir}/*
if [ $? -ne 0 ]
then
	echo "ERROR: Truncate of bulkloadLogdir [$bulkloadLogdir] failed, aborting"
	exit
else
	echo "Done"
	echo
fi

# build zipfile list
zipList=${workDir}/ziplist

echo "[$AWS s3 ls --endpoint-url  ${endpointURL}:${endpointPort} ${sourceS3URL} --profile ${s3ProfileName} --no-verify-ssl | grep \".ZIP\" > ${zipList}]"
$AWS s3 ls --endpoint-url  ${endpointURL}:${endpointPort} ${sourceS3URL} --profile ${s3ProfileName} --no-verify-ssl | grep ".ZIP" > ${zipList}

echo
echo
echo
echo
echo
echo
echo "--| Process Files"
echo
echo

#-- Loop through source zip files
#for I in $( ls ${sourceDir}/*.ZIP )
exec < ${zipList}
while read line
do

	set - $line
	I="$4"
	echo "[$I]"
	srcZipFile=$( basename $I )
	echo "srcZipFile [$srcZipFile]"

	if [ $actionTAG -eq 2 ]
	then
		echo "===== setting srcZipFile = $processFile ===="
		srcZipFile="$processFile"
	fi

	echo "COPY sourcefile [$srcZipFile] to workDir [$workDir]"
	echo "[$AWS s3 cp --endpoint-url  ${endpointURL}:${endpointPort} ${sourceS3URL}${srcZipFile} ${workDir}/ --profile ${s3ProfileName} --no-verify-ssl]"
	$AWS s3 cp --endpoint-url  ${endpointURL}:${endpointPort} ${sourceS3URL}${srcZipFile} ${workDir}/ --profile ${s3ProfileName} --no-verify-ssl
	if [ $? -ne 0 ]
	then
		echo "COPY sourcefile [$srcZipFile] to workDir [$workDir] failed, aborting"
		exit
	else
		echo "Done"
		echo
	fi
	echo
	echo
	echo
	echo
	echo
	echo
	echo "--| UNZIP File"
	echo
	echo

	#-- unzip workfile
	echo "UNZIP workfile [${workDir}/${srcZipFile}]"
	echo "[${UNZIP} ${workDir}/${srcZipFile} -d ${workDir}]"
	${UNZIP} ${workDir}/${srcZipFile} -d ${workDir}
	if [ $? -ne 0 ]
	then
		echo "UNZIP workfile [${workDir}/${srcZipFile}] failed, aborting"
		exit
	else
		echo "Done"
		echo
	fi


	#-- parse file info
	echo
	echo
	echo
	echo
	echo
	echo
	echo "--| Create bulkload control file"
	echo
	echo

	unZipFile=$( basename $srcZipFile .ZIP )
	echo "unZipFile [$unZipFile]"

	IFS=${IFS}.
	set - $unZipFile
	IFS="$OLDIFS"
	#db2ENV_UPPER="$1"
	tabName_UPPER="$1"
	fileDT="$3"
	fileEXT_UPPER="TXT"

	db2ENV=$( echo ${db2ENV_UPPER,,} )
	tabName=$( echo ${tabName_UPPER,,} )
	fileEXT=$( echo ${fileEXT_UPPER,,} )


	#echo "DB2 ENV [$db2ENV]"
	echo "tablename [$tabName]"
	echo "fileDT [$fileDT]"
	echo "file EXT [$fileEXT]"



	#-- Generate control file
	CTLFILE=${workDir}/${tabName}.load.ctl
	echo "INPUT = ${workDir}/${unZipFile}.TXT" > ${CTLFILE}
	echo "TABLE = ${dbSchema}.${tabName}" >> ${CTLFILE}
	echo "PARSE_BADFILE = ${bulkloadLogdir}/${tabName}.bad.log" >> ${CTLFILE}
	echo "LOGFILE = ${bulkloadLogdir}/${tabName}.log" >> ${CTLFILE}
	#${CAT} $BULKCTLTEMPLATE >> ${CTLFILE}
	echo "TRUNCATE = NO" >> ${CTLFILE}
	echo "DELIMITER = ^" >> ${CTLFILE}
	echo "VERBOSE = YES" >> ${CTLFILE}
	echo "MULTI_PROCESS = YES" >> ${CTLFILE}
	echo "NULL = \N" >> ${CTLFILE}
	echo "ON_DUPLICATE_KEEP = OLD" >> ${CTLFILE}
	echo "DUPLICATE_ERRORS = INFINITE" >> ${CTLFILE}
	echo "PARSE_ERRORS = INFINITE" >> ${CTLFILE}



	echo
	echo
	echo
	echo
	echo
	echo
	echo "--| Execute bulkload "
	echo
	echo
	#echo "[${BULKLOAD} -h ${dbHost} -d ${dbName} ${CTLFILE}]"
	#${BULKLOAD} -h ${dbHost} -d ${dbName} ${CTLFILE}
	echo "[${BULKLOAD} -d ${dbName} ${CTLFILE}]"
	${BULKLOAD} -d ${dbName} ${CTLFILE}
	if [ $? -eq 0 ]
	then
		echo
		echo
		echo
		echo
		echo
		echo
		echo "--| Copy source file to archive s3 bucket"
		echo
		echo
		echo "Moving [${sourceDir}/${srcZipFile}] to  [archive]"
		echo "[$AWS s3 cp --endpoint-url  ${endpointURL}:${endpointPort} ${workDir}/${srcZipFile} ${sourceS3URL}archive/ --profile ${s3ProfileName} --no-verify-ssl]"
		$AWS s3 cp --endpoint-url  ${endpointURL}:${endpointPort} ${workDir}/${srcZipFile} ${sourceS3URL}archive/ --profile ${s3ProfileName} --no-verify-ssl
		if [ $? -eq 0 ]
		then
			echo
			echo
			echo
			echo
			echo
			echo
			echo
			echo "--| Remove file from original s3 bucket"
			echo
			echo
			echo "[$AWS s3 rm --endpoint-url  ${endpointURL}:${endpointPort} ${sourceS3URL}${srcZipFile} --profile ${s3ProfileName} --no-verify-ssl]"
			$AWS s3 rm --endpoint-url  ${endpointURL}:${endpointPort} ${sourceS3URL}${srcZipFile} --profile ${s3ProfileName} --no-verify-ssl
			if [ $? -ne 0 ]
			then
				echo
				echo "ERROR: s3 rm of original file failed, aborting"
				echo
				exit
			else
				echo "s3 rm of original file successful"
				echo
			fi


		else
			echo
			echo "ERROR: s3 cp to archive folder failed, aborting"
			echo
			exit
		fi
	else
		echo
		echo
		echo
		echo
		echo
		echo
		echo "--| Copy source file to failed s3 bucket"
		echo
		echo
		echo "Moving [${sourceDir}/${srcZipFile}] to  [failed]"
		echo "[$AWS s3 cp --endpoint-url  ${endpointURL}:${endpointPort} ${workDir}/${srcZipFile} ${sourceS3URL}failed/ --profile ${s3ProfileName} --no-verify-ssl]"
		$AWS s3 cp --endpoint-url  ${endpointURL}:${endpointPort} ${workDir}/${srcZipFile} ${sourceS3URL}failed/ --profile ${s3ProfileName} --no-verify-ssl
		if [ $? -ne 0 ]
		then
			echo
			echo "ERROR: s3 copy source file to failed dir failed, aborting"
			echo
			exit
		else
			echo "s3 copy source file to failed dir successful"
			echo "--| Remove file from original s3 bucket"
			echo
			echo
			echo "[$AWS s3 rm --endpoint-url  ${endpointURL}:${endpointPort} ${sourceS3URL}${srcZipFile} --profile ${s3ProfileName} --no-verify-ssl]"
			$AWS s3 rm --endpoint-url  ${endpointURL}:${endpointPort} ${sourceS3URL}${srcZipFile} --profile ${s3ProfileName} --no-verify-ssl
			if [ $? -ne 0 ]
			then
				echo
				echo "ERROR: s3 rm of original file failed, aborting"
				echo
				exit
			else
				echo "s3 rm of original file successful"
				echo
			fi
		fi

	fi
	echo
	echo
	echo
	echo
	echo
	echo
	echo "--| Remove ZIP file and UNZIPPED file from workdir"
	echo
	echo
	echo "[$RM -f ${workDir}/${srcZipFile}]"
	$RM -f ${workDir}/${srcZipFile}
	echo
	echo "[$RM -f ${workDir}/${unZipFile}.TXT]"
	$RM -f ${workDir}/${unZipFile}.TXT
	echo



	if [ $loopIND -eq 0 ]
	then
		echo "loop set to 0, exiting after first source file"
		echo
		exit
	fi
done

echo "Cleanup"
$RM $zipList
$RM $CTLFILE
echo
echo
echo "Done"
echo
