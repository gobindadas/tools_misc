# network_perf.sh
Collect network bandwidth and latency information between a distributed set of systems.

This script uses iperf3, to get network bandwidth between the hosts,
and ping, to get network latency.  The results are gathered into a
timestamped sub-directory, by default in the working directory.

## Usage

Edit the HOSTS variable in the script to reflect the names or IPs of
the systems between which n/w performance is to be measured. 

e.g:
```
HOSTS="h2-10ge h3-10ge"
```

passwordless ssh to these hosts must work. To check connectivity, do:

```
./network_perf.sh check
```

To perform a test, do:

```
./network_perf.sh test
```

Output is gathered into a directory like this: 
```
run_2019-07-11_1562839237
```

Files within the directory are named by the utility and by the hosts involved, like this: 
```
iperf3.client_h3-10ge.server_h2-10ge.txt
ping.client_h3-10ge.server_h2-10ge.txt
iperf3.server_h2-10ge.txt
```

These files hold the output. The "iperf3" prefixed files give n/w
bandwidth results and the "ping" prefixed files give n/w latency.

By default, the first host in the HOSTS list is picked as the lead.
iperf3 is started in server mode on the lead, following which iperf3
bandwidth test and ping latency test is run to the lead from every
host. The behavior can be changed so that each host takes a turn as
the lead, thereby measuring traffic in both directions. This can be
done by setting a variable in the script:
```
ALL_TO_ALL="y"
```
## Prerequisites

1. passwordless ssh should work between hosts.
1. iperf3 should be installed on all hosts.
1. port used by iperf3 in server mode (5201/tcp by default) should be open.

## Options

1. Change the DEST_DIR variable in the script to control where the results directory is created. 
1. Set the IPERF3_PORT variable in the script if the port used by iperf3 needs to be changed.
1. Set the IPERF3_STREAMS variable in the script to use multiple parallel streams.  With bonding, set this to the number of interfaces bonded together.

