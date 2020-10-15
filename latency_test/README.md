# latency_test

This script can be used to test the suitability of devices for 
etcd, which is known to be latency-sensitive.

## Pre-requisites

- Install Python3 (>= 3.6) and the following packages:
    - pyyaml (pip3 install pyyaml)
    - jinja1 (pip3 install jinja2)
- Install fio (>= 3.5)

## Getting Started

- clone the repository
```
git clone https://github.com/manojtpillai/tools_misc.git
cd tools_misc/latency_test
```
- Edit the input file, params.yaml, to specify options for running the test
    - Specify an output directory. 
    Output for each run will be stored in a timestamped subdirectory 
    under this directory.
    - Edit the etcd_dirlist option to specify the list of mountpoints 
    for which latency is to be tested.
- Run the test
```
./latency_test.py -i params.yaml
```

