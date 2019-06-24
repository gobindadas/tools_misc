#! /bin/bash

set -e 
ME=`basename $0`

# TODO: allow parameter defaults to be modified via command-line
#       options rather than by editing script
# parameters section: BEGIN

# put list of hosts here. passwordless ssh to these should work
HOSTS="localhost"
# HOSTS="h2 h3"

MON_INTRVL=10
MON_DURATION=300

# output files are collected into a sub-dir here
DEST_DIR="."

# parameters section: END

# commands and output-file-prefixes
CMDS="sar iostat top vmstat"
CMD_FILES="sar iostat top vmstat"

function print_usage
{
    echo "Usage: $ME"
    echo "       $ME {check|start|stop|cleanup}"
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

function start_commands
{
    echo
    echo "starting stats collection on hosts..."
    for h in ${HOSTS}; do
	echo -n "${h}: "
	ssh ${h} "nohup sar -n DEV -BdpqruW $MON_INTRVL > /tmp/sar.${h}.txt 2>&1 < /dev/null &"
	ssh ${h} "nohup iostat -dkNtx $MON_INTRVL > /tmp/iostat.${h}.txt 2>&1 < /dev/null &"
	ssh ${h} "nohup top -bH -d $MON_INTRVL > /tmp/top.${h}.txt 2>&1 < /dev/null &"
	ssh ${h} "nohup vmstat -t $MON_INTRVL > /tmp/vmstat.${h}.txt 2>&1 < /dev/null &"
	echo "done"
    done
    echo
}

function stop_commands
{
    echo
    echo "stopping stats collection on... "
    for h in ${HOSTS}; do
	echo -n "${h}: "
	for cmd in ${CMDS}; do
	    ssh ${h} "pkill -x ${cmd}"
	done
	echo "done"
    done
    echo
}

function stop_n_gather
{
    local ts
    local stats_dir

    stop_commands

    ts=`date +"%F_%s"`
    stats_dir="${DEST_DIR}/run_${ts}"
    mkdir ${stats_dir}

    echo "gathering stats from... "
    for h in ${HOSTS}; do
	echo -n "${h}: "
	for prfx in ${CMD_FILES}; do
	    scp -q ${h}:/tmp/${prfx}.${h}.txt ${stats_dir}
	done
	echo "done"
    done
    echo "stats gathered in directory: ${stats_dir}"
}

if [ $# -eq 0 ]; then
    :
elif [ "$1" = "check" ]; then
    ssh_check
    exit 0
elif [ "$1" = "start" ]; then
    start_commands
    exit 0
elif [ "$1" = "stop" ]; then
    stop_n_gather
    exit 0
elif [ "$1" = "cleanup" ]; then
    set +e
    stop_commands
    exit 0
else
    print_usage
    exit 1
fi

start_commands

trap 'stop_n_gather' SIGINT

echo -n "monitoring for ${MON_DURATION} seconds:"
date
sleep ${MON_DURATION}
echo -n "monitoring done:"
date

stop_n_gather

