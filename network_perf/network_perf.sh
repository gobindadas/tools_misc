#! /bin/bash

set -e 
ME=`basename $0`

# parameters section: BEGIN

# put list of hosts here. passwordless ssh to these should work.
HOSTS="localhost"
# HOSTS="h2 h3"

# output files are collected into a sub-dir here
DEST_DIR="."

PING_DURATION=10
IPERF3_DURATION=30

# port for iperf3 to use, in case default is not suitable
# IPERF3_PORT=5201

# number of parallel streams
# with bonding set this to the number of interfaces bonded 
# IPERF3_STREAMS=1

# by default, traffic is from every host to one lead host
# set to "y", to have each host take a turn as lead host;
# this measures traffic for all combinations.
ALL_TO_ALL="n"

# parameters section: END

if [ "${ALL_TO_ALL}" = "n" ]; then
    LEAD_HOSTS=`echo $HOSTS | awk '{print $1}'`
else
    LEAD_HOSTS="${HOSTS}"
fi

function print_usage
{
    echo "Usage: $ME {test|check}"
}

function ssh_check
{
    local host

    echo
    echo "checking ssh connectivity... "
    for host in ${HOSTS}; do
        echo -n "${host}: "
        ssh -o ConnectTimeout=20 ${host} "hostname"
    done
    echo "passed!"
    echo
}

function perform_tests
{

    local port_option client_option
    local lead host

    port_option=""
    if [ ! -z "${IPERF3_PORT}" ]; then
	port_option="-p ${IPERF3_PORT}"
    fi

    client_option="-t ${IPERF3_DURATION}"
    if [ ! -z "${IPERF3_STREAMS}" ]; then
	client_option="${client_option} -P ${IPERF3_STREAMS}"
    fi

    for lead in ${LEAD_HOSTS}; do
	echo "starting iperf3 in server mode on ${lead}"
	ssh $lead "nohup iperf3 -s ${port_option} > /tmp/iperf3.server_${lead}.txt 2>&1 < /dev/null &"

	echo "running tests to ${lead} ..."
	for host in ${HOSTS}; do
	    ssh ${host} "iperf3 -c ${lead} ${client_option} ${port_option} > /tmp/iperf3.client_${host}.server_${lead}.txt"
	    ssh ${host} "ping -c ${PING_DURATION} ${lead} > /tmp/ping.client_${host}.server_${lead}.txt"
	    echo "    ${host} done"
	done
	echo "tests to ${lead} done"

	echo "stopping iperf3 server on ${lead}"
	ssh ${lead} "pkill -x iperf3"
	echo
    done

}

function gather_results
{
    local ts res_dir
    local lead host

    ts=`date +"%F_%s"`
    res_dir="${DEST_DIR}/run_${ts}"
    mkdir ${res_dir}

    for lead in ${LEAD_HOSTS}; do
	scp -q ${lead}:/tmp/iperf3.server_${lead}.txt ${res_dir}
	for host in ${HOSTS}; do
	    scp -q ${host}:/tmp/iperf3.client_${host}.server_${lead}.txt ${res_dir}
	    scp -q ${host}:/tmp/ping.client_${host}.server_${lead}.txt ${res_dir}
	done
    done
    echo "results gathered in directory: ${res_dir}"
}

if [ "$1" = "test" ]; then

    perform_tests
    gather_results
    exit 0

elif [ "$1" = "check" ]; then

    ssh_check
    exit 0

else
    print_usage
    exit 1
fi


