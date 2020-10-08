#!/bin/bash

CMD=$1


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
	:
}

source $BK_SERVER_CONF > /dev/null 2>&1

#
# If the command is pulsar then check if 
#  1) zookeeper nodes &
#  2) bookkeeper nodes 
# are reachable & if not then abort.  
#
if [[ "$CMD" == "pulsar" ]]; then
	reachable=0
	serverList=${zkServers//,/ }
	echo "Checking if Zookeeper servers reachable..."
	for chkCount in $(seq 1 5); do
		for server in $serverList; do
			echo "  * Checking Zookeeper server: $server..."
			if (( $(isZkServerReachable $server) )); then
				reachable=1
				break
			fi
			echo "      $server not reachable."
		done
		if (( $reachable == 1 )); then
			break
		else
			echo "Zookeeper servers are not reachable. Checking again in 3 seconds..."
			sleep 3 
		fi
	done
	if (( $reachable == 1 )); then
		exec gosu pulsar "$@"
	else
		echo "Zookeeper servers are not reachable. Tried 5 times.  Aborting..."
		exit 1
	fi
else
	exec gosu pulsar "$@"
fi


#::END::
