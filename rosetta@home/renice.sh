#!/bin/bash

# output from `numactl -H` less core 6, reserved for F@H GPU process, 18 at end
# as to not use core 6's SMT unless necessary
# provisionOrder=(0 1 2 3 4 5 12 13 14 15 16 17 7 8 9 10 11 19 20 21 22 23 18)

# Numa core 0 reserved for F@H, numa core 1 for for Rosetta, 6/18 for GPU
#provisionOrder=(9 10 11 21 22 23 8 20 7 19)
# Experiment with 23 as extra core
#provisionOrder=(9 10 11 21 22 18 8 20 7 19)

#provisionOrder=(13 14 15 16 17 19 20 21 22 23)
#provisionOrder=(4 2 5 3 1 0 11 9 10 16 17 19 20 21 22 23)

#provisionOrder=(0-2 0-2 0-2 3-5 3-5 3-5 3-5 12-14 12-14 12-14 12-14 15-17 15-17 15-17 15-17)
provisionOrder=(0-2,12-14 0-2,12-14 0-2,12-14 3-5,15-17 3-5,15-17 3-5,15-17 3-5,15-17 0-2,12-14 0-2,12-14 0-2,12-14 0-2,12-14 3-5,15-17 3-5,15-17 3-5,15-17 3-5,15-17)

SETNAME=cpuRosetta
#CPUSPEC=7-11,19-23
#CPUSPEC=0-5,18-23
#CPUSPEC=0-5,7-10
#CPUSPEC=0-5,8-11
#CPUSPEC=0-5,7-17,19-23 # decent config
#CPUSPEC=0-5,7-17
CPUSPEC=0-5,12-17

cset set -m 0 -s $SETNAME -c $CPUSPEC
echo 0 > /sys/fs/cgroup/cpuset/${SETNAME}/cpuset.sched_load_balance
curProc=0
for pid in $(pgrep rosetta); do
	cset proc -m --threads -p $pid -t $SETNAME
	taskset -pc ${provisionOrder[$curProc]} $pid
	#taskset -pc $CPUSPEC $pid
	#taskset -pc 7-11,18-23 $pid
	#taskset -pc 0-23 $pid
	((curProc=curProc+1))
done
