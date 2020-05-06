#!/bin/bash

#cset:
#         Name       CPUs-X    MEMs-X Tasks Subs Path
# ------------ ---------- - ------- - ----- ---- ----------
#         root       0-23 y     0-1 y   279    6 /
#   cpuRosetta  0-5,12-17 n       0 n    18    0 /cpuRosetta
#      cpuCrit 7-17,19-23 n     0-1 n    20    0 /cpuCrit
#         cpuK 7-17,19-23 n     0-1 n    47    0 /cpuK
#    cpuFAHGPU       6,12 n       1 n    59    0 /cpuFAHGPU
#      cpuUser       7-10 n       1 n   254    0 /cpuUser
#    cpuFAHCPU 11-17,19-23 n     0-1 n    14    0 /cpuFAHCPU

# Global nicing
FAHCLIENTUID=123
renice -n 5 -u $FAHCLIENTUID
ionice -c 2 -n 2 -u $FAHCLIENTUID


# Move important stuff to special group
CRITCPUSPEC=7-17,19-23
CRITSETNAME=cpuCrit
if [ ! -d "/sys/fs/cgroup/cpuset/${CRITSETNAME}" ]; then
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
fi


# Wrangle user threads
USERCPUSPEC=7-10
USERSETNAME=cpuUser
if [ ! -d "/sys/fs/cgroup/cpuset/${USERSETNAME}" ]; then
	cset set -m 1 -c $USERCPUSPEC -s $USERSETNAME
fi
cset proc -m --threads -f root -t $USERSETNAME

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


GPUSETNAME=cpuFAHGPU
#GPUCPUSPEC=6-8,12-14
GPUCPUSPEC=6,12
if [ ! -d "/sys/fs/cgroup/cpuset/${GPUSETNAME}" ]; then
	cset set -m 1 -s $GPUSETNAME -c $GPUCPUSPEC
	#echo 1 > /sys/fs/cgroup/cpuset/${GPUSETNAME}/cpuset.sched_load_balance
fi

GPUCORE=6
for pid in $(pgrep FahCore_22); do
	cset proc -m --threads -p $pid $GPUSETNAME
	taskset -pc $GPUCORE $pid
	renice -n 0 $pid
	ionice -c 1 -n 0 -p $pid 
	#chrt -f -p 99 $pid
done

CPUSETNAME=cpuFAHCPU
#CPUSPEC=0-5,7-17,18-23
#CPUSPEC=0-23
#CPUSPEC=7-17,21-23
#CPUSPEC=7-11,19-23
#CPUSPEC=3-5,9-11,12-17,21-23
#CPUSPEC=3-5,9-11,12-17,19-23
#CPUSPEC=0-5,6,7-11,12-14
#CPUSPEC=0-5,7-11
CPUSPEC=11-17,19-23  # <--- very good config
#CPUSPEC=7,12-17,19-23
#CPUSPEC=9-17,21-23

if [ ! -d "/sys/fs/cgroup/cpuset/${CPUSETNAME}" ]; then
	cset set -m 0-1 -s cpuFAHCPU -c $CPUSPEC
	echo 1 > /sys/fs/cgroup/cpuset/${CPUSETNAME}/cpuset.sched_load_balance
fi

for pid in $(pgrep FahCore_a7); do
	cset proc -m --threads -p $pid cpuFAHCPU
	#taskset -a -pc $CPUSPEC $pid
	threads="$(taskset -a -pc $pid | cut -d' ' -f 2 | cut -d "'" -f 1)"
	curThread=0
	# For some reason F@H has extra threads that just sleep, which is
	# why we wrap around here
	#assignOrder=(1 0 2 3 4  5  12 13 14 15 16 17 0 2 3 4)
	#assignOrder=(7 6 8 9 10 11 12 13 14 15 16 17 6 8 9 10)
	#assignOrder=(4 3  5  9  10 11 15 16 17 21 22 23 3  5  9  10)
	assignOrder=(12 11 13 14 15 16 17 19 20 21 22 23 11 13 14 15) # <-- very good config
	#assignOrder=(12  7  13 14 15 16 17 19 20 21 22 23 7  13 14 15)
	#assignOrder=("0-2" "15-17" "15-17" "3-5" "3-5" "3-5" "12-14" "12-14" "12-14" "15-17" "15-17" "15-17" "0-2" "0-2" "12-14" "15-17")
	for thread in $threads; do
		taskset -pc ${assignOrder[$curThread]} $thread
		renice -n -15 -p $thread
		((curThread=curThread+1))
	done

done
