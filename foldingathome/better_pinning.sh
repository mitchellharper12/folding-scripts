#!/bin/bash

set -v

FAH=/cpuFAH
CPU=$FAH/cpuFAHCPU
GPU=$FAH/cpuFAHGPU
#CPUSPEC=0-10,12
#CPUSPEC=0-10,12
#CPUSPEC=12-23
#CPUSPEC=0-11
CPUSPEC=10,12-22
GPUSPEC=11,23
#GPUSPEC=12
#GPUSPEC=11
#OTHERSPEC=12-23
#OTHERSPEC=0-11
OTHERSPEC=0-9
#OTHERSPEC=0-10
#OTHERSPEC=13-23

# Wrangle user threads
USERCPUSPEC=$OTHERSPEC
USERSETNAME=cpuUser
#if [ ! -d "/sys/fs/cgroup/cpuset/${USERSETNAME}" ]; then
	cset set -m 1 -c $USERCPUSPEC -s $USERSETNAME
#fi
cset proc -m --threads -f root -t $USERSETNAME

#EXCLUSIVE=1
EXCLUSIVE=1
cset set -s $FAH -c $CPUSPEC,$GPUSPEC -m 0-1
#cset set -s $FAH -c 0-23 -m 0-1
echo $EXCLUSIVE > /sys/fs/cgroup/cpuset/$FAH/cpuset.cpu_exclusive
cset set -s $CPU -c $CPUSPEC -m 0-1
cset set -s $GPU -c $GPUSPEC -m 1
echo $EXCLUSIVE > /sys/fs/cgroup/cpuset/$CPU/cpuset.cpu_exclusive
echo $EXCLUSIVE > /sys/fs/cgroup/cpuset/$GPU/cpuset.cpu_exclusive
# We only will care about threads with at least 90% CPU utilization
worker_threads="$(ps -Teo pcpu,tid,comm | grep FahCore_a7.orig | grep "^9.\." | awk '{ print $2 }')"
#echo $worker_threads

#provision_order=({6..17})
#provision_order=({12..23})
#provision_order=({0..10} 12)
provision_order=(10 {12..22})
#provision_order=({0..11})
cur_proc=0
for thread in $worker_threads; do
	cset proc -m -p $thread -t $CPU
	taskset -pc ${provision_order[$cur_proc]} $thread 
	((cur_proc=cur_proc+1))
done

GPUCORE=11
for pid in `pgrep FahCore_22`; do
	cset proc -m -p $pid -t $GPU
	#taskset -pc $GPUSPEC $pid
	taskset -pc $GPUCORE $pid
done

# Move important stuff to special group
CRITCPUSPEC=$OTHERSPEC
CRITSETNAME=cpuCrit
#if [ ! -d "/sys/fs/cgroup/cpuset/${CRITSETNAME}" ]; then
	cset set -m 0-1 -c $CRITCPUSPEC -s $CRITSETNAME
	for pid in `pgrep pulseaudio`; do
		cset proc -m --threads -p $pid -t $CRITSETNAME
	done

	for pid in `pgrep rtkit-daemon`; do
		cset proc -m --threads -p $pid -t $CRITSETNAME
	done

	for pid in `pgrep systemd-journald`; do
		cset proc -m --threads -p $pid -t $CRITSETNAME
	done

	for pid in `pgrep upowerd`; do
		cset proc -m --threads -p $pid -t $CRITSETNAME
	done

	for pid in `pgrep systemd`; do
		cset proc -m --threads -p $pid -t $CRITSETNAME
	done

	for pid in `pgrep dbus-daemon`; do
		cset proc -m --threads -p $pid -t $CRITSETNAME
	done
#fi


# Move important procs back to root
# init
cset proc -m -p 1 -t root

# Folding cores and wrappers, so that numactl runs properly
for pid in `pgrep FAHC`; do
	cset proc -m --threads -p $pid -t root
done

# sshd so subshells aren't restricted
for pid in `pgrep sshd`; do
	cset proc -m --threads -p $pid -t root
done

# existing bash shells
for pid in `pgrep bash`; do
	cset proc -m --threads -p $pid -t root
done

# existing tmux sessions
for pid in `pgrep tmux`; do
	cset proc -m --threads -p $pid -t root
done
