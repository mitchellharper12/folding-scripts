#!/bin/bash

#CPUSPEC=0-23
#CPUSPEC=23
CPUSPEC=$1
echo $CPUSPEC > /proc/irq/1/smp_affinity_list
AFFINITY="$(cat /proc/irq/1/smp_affinity)"

echo $AFFINITY > /proc/irq/default_smp_affinity

for file in `find /proc/irq -name smp_affinity_list`; do
	echo $CPUSPEC > $file 2>/dev/null
done

# Kernel threadwerk
KERNELSETNAME=cpuK
#if [ ! -d "/sys/fs/cgroup/cpuset/${KERNELSETNAME}" ]; then
	cset set -m 0 -s $KERNELSETNAME -c $CPUSPEC
#fi

cset proc -k -f root -t $KERNELSETNAME
