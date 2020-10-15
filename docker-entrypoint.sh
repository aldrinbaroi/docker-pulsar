#!/bin/bash

source lib/dependency-manager

CMD=$1
MODULE=$2 

# Create configuration files if the files don't exist 
if [[ ! -f "${BROKER_CONF}" ]]; then
	source /gen-broker.conf
fi
if [[ ! -f "${CLIENT_CONF}" ]]; then
	source /gen-client.conf
fi
if [[ ! -f "${PROXY_CONF}" ]]; then
	source /gen-proxy.conf
fi
if [[ ! -f "${DISCOVERY_CONF}" ]]; then
	source /gen-discovery.conf
fi
if [[ ! -f "${WEBSOCKET_CONF}" ]]; then
	source /gen-websocket.conf 
fi
if [[ ! -f "${ZOOKEEPER_CONF}" ]]; then
	source /gen-zookeeper.conf 
fi
if [[ ! -f "${GLOBAL_ZOOKEEPER_CONF}" ]]; then
	source /gen-global_zookeeper.conf 
fi
if [[ ! -f "${BOOKKEEPER_CONF}" ]]; then
	source /gen-bookkeeper.conf 
fi
if [[ ! -f "${STANDALONE_CONF}" ]]; then
	source /gen-standalone.conf 
fi 

isZkServerReachable()
{
        local zkServer=$1
        local hostAndPort=""
        local host=""
        local port=0
        IFS=':' read -r -a hostAndPort <<< "$zkServer"
        host=${hostAndPort[0]}
        port=${hostAndPort[1]}
        if (( $(echo srvr | nc $host $port > /dev/null 2>&1; echo $?) )); then
                echo 0
        else
                echo 1
        fi 
} 

isBookKeeperServerReachable()
{
        local bkServer=$1
        local hostAndPort=""
        local host=""
        local port=0
        IFS=':' read -r -a hostAndPort <<< "$bkServer"
        host=${hostAndPort[0]}
        port=${hostAndPort[1]}
        if (( $(nc -z $host $port > /dev/null 2>&1; echo $?) )); then
                echo 0
        else
                echo 1
        fi 
}

areServersReachable() {
	local serverType=$1
	local checkFunc=$2
	local servers=$3	
	local reachable=0
	local serverList=${servers//,/ }
	local chkCount
	local server
	if [[ -z "$serverType" ]]; then
		abort "Server type not provided."
	fi
	if [[ -z "$checkFunc" ]]; then
		abort "Check function is not provided."
	fi
	if [[ -z "$servers" ]]; then
		abort "Servers list not provided."
	fi
	log "Checking if $serverType servers [$serverList] are reachable..."
	for chkCount in $(seq 1 5); do
		for server in $serverList; do
			log "  * Checking $serverType server: $server..."
			if (( $($checkFunc $server) )); then
				reachable=1
				break
			fi
			log "      $server not reachable."
		done
		if (( $reachable == 1 )); then
			break
		else
			log "$serverType servers [$serverList] are not reachable. Checking again in 3 seconds..."
			sleep 3 
		fi
	done
	if (( $reachable == 0 )); then
		abort "$serverType servers are not reachable. Tried 5 times.  Aborting..."
	fi
}

initCluster()
{
	local CLUSTER_NAME=$1
	local PULSAR_HOSTNAME=$2
	if [[ -z "$CLUSTER_NAME" ]]; then
		abort "Cluster name not provided."
	fi
	if [[ -z "$PULSAR_HOSTNAME" ]]; then
		abort "Pulsar hostname not provided."
	fi
	INIT_CMD="initialize-cluster-metadata 
			--cluster \"$CLUSTER_NAME\"
			--zookeeper \"$zookeeperServers\" 
			--configuration-store \"$configurationStoreServers\" 
			--web-service-url \"http://$PULSAR_HOSTNAME:$webServicePort\"/ 
			--broker-service-url \"pulsar://$PULSAR_HOSTNAME:$brokerServicePort/\" "
	if [[ ! -z "webServicePortTls" ]]; then
		$INIT_CMD+=" --web-service-url-tls \"https://$PULSAR_HOSTNAME:$webServicePortTls\"/"
	fi
	if [[ ! -z "webServicePortTls" ]]; then
		$INIT_CMD=" --broker-service-url-tls \"pulsar+ssl://$PULSAR_HOSTNAME:$brokerServicePort/\""
	fi
	exec gosu pulsar pulsar $INIT_CMD
	if (( $? )) ; then
		log "Failed to initialize the cluster"
	else
		log "Successfully initialized the cluster"
	fi
} 

declare -A CONF_FILES
CONF_FILES['broker']=$BROKER_CONF
CONF_FILES['bookie']=$BOOKKEEPER_CONF
CONF_FILES['zookeeper']=$ZOOKEEPER_CONF
CONF_FILES['global-zookeeper']=$GLOBAL_ZOOKEEPER_CONF
CONF_FILES['discovery']=$DISCOVERY_CONF
CONF_FILES['proxy']=$PROXY_CONF
CONF_FILES['websocket']=$WEBSOCKET_CONF
CONF_FILES['standalone']=$STANDALONE_CONF
CONF_FILES['client']=$CLIENT_CONF

loadPropertiesFile $BROKER_CONF 

#
# If the command is pulsar then check if 
#  1) zookeeper nodes &
#  2) bookkeeper nodes 
# are reachable & if not then abort.  
#
if [[ "$CMD" == "pulsar" ]]; then 
	if [[ -z "$MODULE" ]]; then
		# default module
		MODULE="broker"  
	fi
	areServersReachable "Local Zookeeper" isZkServerReachable "$zookeeperServers"
	areServersReachable "Configuration Store" isZkServerReachable "$configurationStoreServers"
	case "$MODULE" in
		broker)
			if [[ ! -z "${bookkeeperMetadataServiceUri}" ]]; then
				bookkeeperZookeeperServers="$(echo ${bookkeeperMetadataServiceUri} | sed 's/.*[/][/]//; s/[/].*//; s/[;]/,/')"
				areServersReachable "External Bookkeeper's Zookeeper" isZkServerReachable "$bookkeeperZookeeperServers"
			fi
			exec gosu pulsar pulsar broker
			;;
		*)
			shift 1
			loadPropertiesFile ${CONF_FILES[$MODULE]} 
			exec gosu pulsar pulsar "$@"
			;;
	esac
elif [[ "$CMD" == "initCluster" ]]; then
	areServersReachable "Local Zookeeper" isZkServerReachable "$zookeeperServers"
	areServersReachable "Configuration Store" isZkServerReachable "$configurationStoreServers"
	shift 1
	initCluster "$@" 
else
	exec gosu pulsar "$@"
fi 

#::END::
