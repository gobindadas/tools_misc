# stats_collect.sh
Collect system statistics from a distributed set of systems.

This script can be used to gather stats (sar, iostat etc.) from a set
of systems for a period of time. The stats are gathered into a
single timestamped sub-directory, by default in the working directory.

## Basics

Edit the HOSTS variable in the script to reflect the names or IPs of
the systems on which stats collection is to be run.

e.g:
```
HOSTS="h1-priv h2-priv"
```

passwordless ssh to these hosts must work. To check connectivity, run:

```
./stats_collect.sh check
```

For a regular run, output is gathered into a directory like this: 
```
run_2019-06-16_1560680886
```

Files within the directory are named by monitoring command and host, like this: 
```
iostat.h2-priv.txt
sar.h3-priv.txt
```

## Modes of Operation 

The script can be used in one of three modes:

### Collect statistics for a fixed duration.

For example, to collects stats for a duration of 10 minutes, edit the
script to set MON_DURATION=600.

Run the script with no arguments:
```
./stats_collect.sh
```

At the end of MON_DURATION, stats from all the hosts are collected
into a timestamped directory.

### Collects statistics for a duration, not known ahead of time.

Set MON_DURATION in the script to a higher value than the expected
duration, run the script with no arguments:
```
./stats_collect.sh
```

Hit Ctrl-C when you are ready to stop monitoring and gather the stats.
Stats from all hosts from start of script are collected into a
timestamped directory.


### Collects statistics for the duration of a command/benchmark.
```
./stats_collect.sh start
[command]
./stats_collect.sh stop
```

## Extras

- Check ssh connectivity and verify that hosts are correctly specified:
```
./stats_collect.sh check
```

- Clean up any monitoring commands from a run that didn't complete cleanly:
```
./stats_collect.sh cleanup
```

