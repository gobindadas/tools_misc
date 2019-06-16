# stats_collect
Collect system statistics from a distributed set of systems.


## Basics

Edit the script to add the systems on which stats collection is to be run.

HOSTS="h1 h2"

passwordless ssh to these hosts must work.

## Modes of Operation 

The script is useful in one of three modes:

### Collect statistics for a fixed duration.

For example, to collects stats for a duration of 10 minutes, edit the
script to set MON_DURATION=600.

Run the script with no arguments:
./stats_collect.sh

At the end of MON_DURATION, stats from all the hosts are collected
into a timestamped directory.

### Collects statistics for a duration, not known ahead of time.

Set MON_DURATION in the script to a high value, run the script with no
arguments:
./stats_collect.sh

Hit Ctrl-C when done. Stats from all hosts upto that time are
collected into a timestamped directory.


### Collects statistics for the duration of a command/benchmark.

./stats_collect.sh start
[command]
./stats_collect.sh stop


## Extras

1. Check ssh connectivity and verify that hosts are correctly specified:
./stats_collect.sh check

1. Stop any monitoring commands from a run that didn't complete cleanly:
./stats_collect.sh cleanup

