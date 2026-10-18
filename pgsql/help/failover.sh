#
# Ansible managed
#
#!/bin/bash

pgpoolBase=/apps/lib/pgsql/pgpool
siteNameFile=${pgpoolBase}/etc/poolSiteName.txt
nodesListFile=${pgpoolBase}/etc/poolNodes.lst
PSQL=/usr/pgsql-14/bin/psql
myIP=""
failedNode="$1"
newMainNode="$2"
oldPrimaryNode="$3"
newPrimaryID=0
ERRstr=""
repMGR=/usr/pgsql-14/bin/repmgr
repMGRconf=/apps/lib/pgsql/14/repmgr/repmgr.conf
repmgrList=/tmp/repmgr.lst
oldIFS="$IFS"
failedNodeID=0
failedNodeName="unset"
failedNodeRole="unset"
newMainNodeID=0
newMainNodeName="unset"
newMainNodeRole="unset"
> $repmgrList


#-- Functions
function log_fatal_error {
	echo
	echo
	echo "---|"
	echo "---| FATAL ERROR"
	echo "---|"
	echo "FATAL: $ERRstr"
	echo "Aborting"
	#-- add alerting here
	exit
}

function get_key_node_info {
	echo
	echo
	echo "---|"
	echo "---| getting failed node info"
	echo "---|"
	IFS=${IFS}=-

	echo
	echo "building the repmgr cluster show listing"
	echo "ssh -n -T  postgres@${newMainNode} \"( ${repMGR} -f ${repMGRconf} cluster show )\" | grep \"host=\" > $repmgrList"
	ssh -n -T  postgres@${newMainNode} "( ${repMGR} -f ${repMGRconf} cluster show )" | grep "host=" > $repmgrList

	echo
	echo "loop through the repmgr cluster show listing and find the failed node"
	exec < $repmgrList
	while read line
	do
		line2=$( echo "$line" | sed "s/*//g" ) # remove problematic * from the line

		echo "$line2" | grep "$failedNode" > /dev/null
		if [ $? -eq 0 ]
		then
			set - $line
			failedNodeID=$1
			failedNodeName="$3"
			failedNodeRole="$5"
		fi

		echo "$line2" | grep "$newMainNode" > /dev/null
		if [ $? -eq 0 ]
		then
			set - $line
			newMainNodeID=$1
			newMainNodeName="$3"
			newMainNodeRole="$5"
		fi
	done
	IFS="$oldIFS"
	echo "end of get_key_node_info"
	echo
}


function execute_failover {
	echo
	echo
	echo "---|"
	echo "---| Executing failover"
	echo "---|"
 	IFS=${IFS}=-
#--
#-- 	echo
#-- 	echo "loop through the repmgr cluster show listing and create replication slots on the newMainNode [$newMainNode]"
#-- 	echo
#-- 	exec < $repmgrList
#-- 	while read line
#-- 	do
#-- 		line2=$( echo "$line" | sed "s/*//g" ) # remove problematic * from the line
#--
#-- 		echo "$line2" | grep "$failedNode" > /dev/null
#-- 		if [ $? -eq 0 ]
#-- 		then
#-- 			continue
#-- 		fi
#--
#-- 		echo "$line2" | grep "$newMainNode" > /dev/null
#-- 		if [ $? -eq 0 ]
#-- 		then
#-- 			continue
#-- 		fi
#--
#-- 		set - $line
#-- 		if [ "$7" == "running" ]
#-- 		then
#-- 			echo "echo \"SELECT pg_create_physical_replication_slot ( '$3' )\" | $PSQL -h ${newMainNode} "
#-- 			#echo "SELECT pg_create_physical_replication_slot ( '$3' )" | $PSQL -h ${newMainNode}
#-- 		fi
#--
#-- 	done

	echo
	echo "Promote the newMainNode [$newMainNode]"
	echo
	echo "ssh -n -T postgres@${newMainNode} \"( ${repMGR} -f ${repMGRconf} standby promote  )\""
	ssh -n -T postgres@${newMainNode} "( ${repMGR} -f ${repMGRconf} standby promote  )"


	echo
	echo "Tell all other running nodes to follow the new primary"
	echo

	exec < $repmgrList
	while read line
	do
		echo "line: [$line]"
		line2=$( echo "$line" | sed "s/*//g" ) # remove problematic * from the line
		echo "line2: [$line2]"

		echo "$line2" | grep "$failedNode" > /dev/null
		if [ $? -eq 0 ]
		then
			echo "found failednode line, skipping"
			continue
		fi

		echo "$line2" | grep "$newMainNode" > /dev/null
		if [ $? -eq 0 ]
		then
			echo "found new main node line, skipping"
			continue
		fi

		set - $line
		echo "[$1] [$2] [$3] [$4] [$5] [$6] [$7] [$8]"
		if [ "$7" == "running" ]
		then
			# loop through line elements and find the hostname
			while [ $# -gt 0 ]
			do
				shift
				if [ "$1" == "host" ]
				then
					echo
					nodeIP="$2"
					echo "nodeIP=[$nodeIP]"
					echo
					break
				fi
			done

			echo "ssh -n -T postgres@${nodeIP} \"( ${repMGR} -f ${repMGRconf} standby follow --upstream-node-id ${newMainNodeID} )\""
			ssh -n -T postgres@${nodeIP} "( ${repMGR} -f ${repMGRconf} standby follow --upstream-node-id ${newMainNodeID} )"
		fi
	done

	echo
	echo "executing unregister of failed node"
	echo "ssh -n -T postgres@${newMainNode} \"( ${repMGR} -f ${repMGRconf} primary unregister --node-id ${failedNodeID} )\""
	ssh -n -T postgres@${newMainNode} "( ${repMGR} -f ${repMGRconf} primary unregister --node-id ${failedNodeID} )"

	IFS="$oldIFS"
}


function unregister_standby {
	echo
	echo
	echo "---|"
	echo "---| Unregistering Failed Standby [$failedNode]"
	echo "---|"
	echo
	echo "executing unregister of failed node"
	echo "ssh -n -T postgres@${newMainNode} \"( ${repMGR} -f ${repMGRconf} standby unregister --node-id ${failedNodeID} )\""
	ssh -n -T postgres@${newMainNode} "( ${repMGR} -f ${repMGRconf} standby unregister --node-id ${failedNodeID} )"
}


#-- Main --#

startDT=$(date)

echo "---|"
echo "---| $0 called at [$startDT]"
echo "---|"

ifCFGline=$( ifconfig | grep inet | grep -v inet6 | grep -v 127.0.0.1 )
set - $ifCFGline
myIP="$2"

siteName=$( cat $siteNameFile )

echo
echo
echo "---|"
echo "---| Passed in parameters and other values"
echo "---|"
echo "failedNode      [$failedNode]"
echo "newMainNode     [$newMainNode]"
echo "oldPrimaryNode  [$oldPrimaryNode]"
echo "myIP            [$myIP]"
echo "siteName        [$siteName]"

echo
echo
echo "---|"
echo "---| Verify that we can read [$nodesListFile]"
echo "---|"
if [ ! -r "$nodesListFile" ]
then
	ERRstr="poolNodes.lst file [$nodesListFile] unreadable or missing"
	log_fatal_error
fi


echo
echo
echo "---|"
echo "---| determine if I am the leader"
echo "---|"
exec < $nodesListFile
while read line
do
	set - $line
	nodeName="$1"
	nodeIP="$2"
	echo
	echo "Checking entries in $nodesListFile"
	echo "[$nodeName]  [$nodeIP]"

	if [ "$nodeIP" == "$myIP" ]
	then
		echo
		echo "I Am the leader [$nodeIP] [$myIP]"
		echo
		echo "determining if the failure was a primary or a standby"
		get_key_node_info

		if [ $failedNodeID -eq 0 -o "$failedNodeName" == "unset" -o "$failedNodeRole" == "unset" ]
		then
			ERRstr="function get_key_node_info returned unexpected results -"
			ERRstr="${ERRstr} failedNodeID:[$failedNodeID]"
			ERRstr="${ERRstr} failedNodeName:[$failedNodeName]"
			ERRstr="${ERRstr} failedNodeRole:[$failedNodeRole]"
			log_fatal_error
		fi

		if [ $newMainNodeID -eq 0 -o "$newMainNodeName" == "unset" -o "$newMainNodeRole" == "unset" ]
		then
			ERRstr="function get_key_node_info returned unexpected results -"
			ERRstr="${ERRstr} newMainNodeID:[$newMainNodeID]"
			ERRstr="${ERRstr} newMainNodeName:[$newMainNodeName]"
			ERRstr="${ERRstr} newMainNodeRole:[$newMainNodeRole]"
			log_fatal_error
		fi

		echo
		echo "failedNodeID    [$failedNodeID]"
		echo "failedNodeName  [$failedNodeName]"
		echo "failedNodeRole  [$failedNodeRole]"
		echo "newMainNodeID   [$newMainNodeID]"
		echo "newMainNodeName [$newMainNodeName]"
		echo "newMainNodeRole [$newMainNodeRole]"


		case $failedNodeRole in
			primary)
				echo
				echo
				echo "---|"
				echo "---| Failed Node was the primary, executing a failover"
				echo "---|"
				execute_failover
				;;


			standby)
				echo
				echo
				echo "---|"
				echo "---| Failed Node was a standby, executing a standby unregister"
				echo "---|"
				unregister_standby
				;;

			*)
				ERRstr="ERROR: failed node neither primary or standby [$failedNodeRole]"
				log_fatal_error
				;;
		esac

		# we're done
		exit
	fi

	ping -c1 $nodeIP
	if [ $? -eq 0 ]
	then
		echo
		echo "Ping Check was Successful"
		echo
		echo "show pool_nodes"  | psql -h $nodeIP
		if [ $? -eq 0 ]
		then
			echo "this guy is the leader [$nodeIP]"
			echo "$nodeIP will perform the failover"
			echo "I will exit now since I am not needed here"
			echo
			exit
		fi
	fi
done
