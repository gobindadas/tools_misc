# latency_test

This script can be used to test the suitability of devices for 
etcd, which is known to be latency-sensitive.

## Pre-requisites

- Install Python3 (>= 3.6) and the following packages:
    - pyyaml (pip3 install pyyaml)
    - jinja2 (pip3 install jinja2)
- Install fio (>= 3.5)

## Getting Started

### Clone the repository
```
git clone https://github.com/manojtpillai/tools_misc.git
cd tools_misc/latency_test
```
### Specify options for the run

- Edit the input file, params.yaml.

- Specify an output directory. Default is current directory.
Output for each run will be stored in a timestamped subdirectory 
under this directory.

- Edit the etcd_dirlist option to specify the list of mountpoints 
for which latency is to be tested.

- specify additional options that allow for concurrent load(s) to be
simulated. The directories (mount points) used for this concurrent
load can different from the etcd_dirlist options.

### Run the test

```
./latency_test.py -i params.yaml
```
### Check the output

Output files are created in the output directory for each load point.
Look for sync latencies for the etc_write job:

```
  fsync/fdatasync/sync_file_range:
    sync (usec): min=328, max=9131, avg=786.72, stdev=321.30
    sync percentiles (usec):
     |  1.00th=[  453],  5.00th=[  510], 10.00th=[  553], 20.00th=[
603],
     | 30.00th=[  644], 40.00th=[  685], 50.00th=[  742], 60.00th=[
799],
     | 70.00th=[  848], 80.00th=[  906], 90.00th=[  996], 95.00th=[
1139],
     | 99.00th=[ 1975], 99.50th=[ 2540], 99.90th=[ 4359], 99.95th=[
5276],
     | 99.99th=[ 7701]
```

Recommended for etcd is p99 latency less than 10ms.

