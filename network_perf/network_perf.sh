#! /bin/bash

set -e 
ME=`basename $0`

# parameters section: BEGIN

# put list of hosts here. passwordless ssh to these should work.
HOSTS="localhost"
# HOSTS="h2 h3"

PING_DURATION=10
IPERF_DURATION=30

# output files are collected into a sub-dir here
DEST_DIR="."

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
    echo
    echo "checking ssh connectivity... "
    for h in ${HOSTS}; do
        echo -n "${h}: "
        ssh -o ConnectTimeout=20 ${h} "hostname"
    done
    echo "passed!"
    echo
}

function perform_tests
{

    for lead in ${LEAD_HOSTS}; do
	echo "starting iperf3 in server mode on ${lead}"
	ssh $lead "nohup iperf3 -s > /tmp/iperf3.server_${lead}.txt 2>&1 < /dev/null &"

	echo "running tests to ${lead} ..."
	for h in ${HOSTS}; do
	    ssh ${h} "iperf3 -c ${lead} -t ${IPERF_DURATION} > /tmp/iperf3.client_${h}.server_${lead}.txt"
	    ssh ${h} "ping -c ${PING_DURATION} ${lead} > /tmp/ping.client_${h}.server_${lead}.txt"
	    echo "    ${h} done"
	done
	echo "tests to ${lead} done"

	echo "stopping iperf3 server on ${lead}"
	ssh ${lead} "pkill -x iperf3"
	echo
    done


}

function gather_results
{
    local ts
    local res_dir

    ts=`date +"%F_%s"`
    res_dir="${DEST_DIR}/run_${ts}"
    mkdir ${res_dir}

    for lead in ${LEAD_HOSTS}; do
	scp -q ${lead}:/tmp/iperf3.server_${lead}.txt ${res_dir}
	for h in ${HOSTS}; do
	    scp -q ${h}:/tmp/iperf3.client_${h}.server_${lead}.txt ${res_dir}
	    scp -q ${h}:/tmp/ping.client_${h}.server_${lead}.txt ${res_dir}
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



