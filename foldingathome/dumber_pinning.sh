#!/bin/bash

# currently value of GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub
# GRUB_CMDLINE_LINUX_DEFAULT="maybe-ubiquity isolcpus=1-23 nohz_full=1-23 mitigations=off"

set -v

FAH=/cpuFAH
CPUSET=$FAH/cpuFAHCPU
GPU=$FAH/cpuFAHGPU

CPUSPEC=2-10,12-22
GPUSPEC=11,23
OTHERSPEC=0-1
CRITCPUSPEC=$OTHERSPEC

# Global nicing
FAHCLIENTUID=123
renice -n -3 -u $FAHCLIENTUID
ionice -c 2 -n 2 -u $FAHCLIENTUID

# Wrangle user threads
USERCPUSPEC=$OTHERSPEC
USERSETNAME=cpuUser
# We now do this with the kernel argument isolcpus
#if [ ! -d "/sys/fs/cgroup/cpuset/${USERSETNAME}" ]; then
#	cset set -m 0 -c $USERCPUSPEC -s $USERSETNAME
#fi
#cset proc -m --threads -f root -t $USERSETNAME

#EXCLUSIVE=1
EXCLUSIVE=1
cset set -s $FAH -c 2-23 -m 0-1
echo $EXCLUSIVE > /sys/fs/cgroup/cpuset/$FAH/cpuset.cpu_exclusive
cset set -s $CPUSET0 -c $CPUSPEC -m 0-1
cset set -s $GPU -c $GPUSPEC -m 1
#cset set -s $GPU_OTHER -c $GPUSPEC -m 1
echo $EXCLUSIVE > /sys/fs/cgroup/cpuset/$CPU/cpuset.cpu_exclusive
echo $EXCLUSIVE > /sys/fs/cgroup/cpuset/$GPU/cpuset.cpu_exclusive

#echo 0 > /proc/sys/kernel/numa_balancing
# We only will care about threads with actual work
worker_threads="$(ps -Teo pcpu,tid,comm | grep FahCore_a7 | grep -v "^ 0.0" | awk '{ print $2 }')"
echo $worker_threads

cur_proc=0
provision_list=({2..10} {12..22})
for thread in $worker_threads; do
	cset proc -m -p $thread -t $CPUSET
	taskset -pc ${provision_list[$cur_proc]} $thread 
	renice -n -15 $thread
	((cur_proc=cur_proc+1))
done

GPUCORE=11,23
for pid in `pgrep FahCore_22`; do
	cset proc -m --threads -p $pid -t $GPU
	#cset proc -m -p $pid -f $GPU_OTHER -t $GPU
	renice -n -19 $pid
	ionice -c 2 -n 0 -p $pid 
done

for pid in `pgrep FahCore_21`; do
	cset proc -m --threads -p $pid -t $GPU
	#cset proc -m -p $pid -f $GPU_OTHER -t $GPU
	renice -n -19 $pid
	ionice -c 2 -n 0 -p $pid 
done
# Move important stuff to special group
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

#	for pid in `pgrep systemd`; do
#		cset proc -m --threads -p $pid -t $CRITSETNAME
#	done

	for pid in `pgrep dbus-daemon`; do
		cset proc -m --threads -p $pid -t $CRITSETNAME
	done
#fi


# Move important procs back to root
# init
#cset proc -m -p 1 -t root

# Folding cores and wrappers, so that numactl runs properly
#for pid in `pgrep FAHC`; do
#	cset proc -m --threads -p $pid -t root
#done

# sshd so subshells aren't restricted
#for pid in `pgrep sshd`; do
#	cset proc -m --threads -p $pid -t root
#done

# existing bash shells
#for pid in `pgrep bash`; do
#	cset proc -m --threads -p $pid -t root
#done

# existing tmux sessions
#for pid in `pgrep tmux`; do
#	cset proc -m --threads -p $pid -t root
#done
